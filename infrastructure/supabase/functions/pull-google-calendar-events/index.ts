// Legge gli eventi nuovi/modificati su Google Calendar per ogni utente collegato e li
// scrive come calendar_events locali (Fase 3, "Sync con Google Calendar" — integrazione
// richiesta esplicitamente, direzione Google → PIP). Invocata da un cron job Postgres
// (`pg_cron`, ogni 10 minuti — vedi il blocco commentato in
// infrastructure/supabase/migrations/20260723170000_google_calendar_sync.sql), non da una
// richiesta di un utente autenticato: non esiste un JWT da inoltrare.
//
// Stessa giustificazione di `send-due-reminders` per l'uso della service role invece del
// JWT di chi chiama: deve leggere calendar_connections di TUTTI gli utenti collegati, non
// solo di un chiamante specifico. Le RLS di calendar_connections/calendar_events restano
// intatte per ogni altro accesso — qui vengono bypassate by design, non aggirate per errore.
//
// Un evento con `google_event_id` già presente localmente non viene mai ricreato (evita un
// loop con la direzione PIP → Google di `sync-calendar-event`); un evento Google con
// `status: "cancelled"` cancella (soft delete) il calendar_events locale corrispondente.

import { createClient } from "npm:@supabase/supabase-js@2";

const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_CALENDAR_API = "https://www.googleapis.com/calendar/v3";

// Limite prudenziale per esecuzione, sia sul numero di connessioni processate sia sugli
// eventi letti per connessione — stesso principio di MAX_OCCURRENCES_PER_RUN in
// create-due-recurring-transactions: un'esecuzione lenta o con molti utenti non deve
// bloccare l'intero cron, il giro successivo (10 minuti dopo) recupera il resto.
const MAX_CONNECTIONS_PER_RUN = 50;
const MAX_EVENTS_PER_CONNECTION = 100;

Deno.serve(async (req) => {
  // Nessun CORS/OPTIONS: questa function non viene mai chiamata da un browser, solo dal
  // cron job Postgres via pg_net (server-to-server) — stesso pattern di send-due-reminders.
  if (req.method !== "POST") {
    return jsonError("Metodo non supportato.", 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const googleClientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const googleClientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");

    if (
      !supabaseUrl || !serviceRoleKey || !googleClientId || !googleClientSecret
    ) {
      console.error(
        "pull-google-calendar-events: variabili d'ambiente mancanti " +
          "(SUPABASE_URL/SERVICE_ROLE_KEY/GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET)",
      );
      return jsonError("Servizio non configurato.", 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: connections, error: connectionsError } = await supabase
      .from("calendar_connections")
      .select("user_id, google_refresh_token, google_calendar_id, sync_token")
      .limit(MAX_CONNECTIONS_PER_RUN);

    if (connectionsError) {
      console.error(
        "pull-google-calendar-events: errore lettura calendar_connections",
        connectionsError,
      );
      return jsonError("Non è stato possibile leggere i collegamenti.", 500);
    }
    if (!connections || connections.length === 0) {
      return new Response(JSON.stringify({ ok: true, processed: 0 }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    let processed = 0;
    for (const connection of connections) {
      const userId = connection.user_id as string;
      try {
        await pullForConnection(
          supabase,
          connection,
          googleClientId,
          googleClientSecret,
        );
        processed += 1;
      } catch (error) {
        // Un utente con un problema (token revocato, rete) non deve bloccare la pull per
        // gli altri: log e si passa al successivo.
        console.error(
          "pull-google-calendar-events: fallita per utente",
          userId,
          error,
        );
      }
    }

    return new Response(
      JSON.stringify({ ok: true, processed, total: connections.length }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (error) {
    console.error("pull-google-calendar-events: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

async function pullForConnection(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  connection: {
    user_id: string;
    google_refresh_token: string;
    google_calendar_id: string;
    sync_token: string | null;
  },
  googleClientId: string,
  googleClientSecret: string,
): Promise<void> {
  const accessToken = await getGoogleAccessToken(
    connection.google_refresh_token,
    googleClientId,
    googleClientSecret,
  );
  if (!accessToken) return;

  const calendarId = connection.google_calendar_id || "primary";
  const params = new URLSearchParams({
    maxResults: String(MAX_EVENTS_PER_CONNECTION),
    singleEvents: "true",
  });
  if (connection.sync_token) {
    params.set("syncToken", connection.sync_token);
  } else {
    // Prima pull per questo utente: solo eventi da adesso in poi, mai l'intera storia.
    params.set("timeMin", new Date().toISOString());
  }

  const response = await fetch(
    `${GOOGLE_CALENDAR_API}/calendars/${
      encodeURIComponent(calendarId)
    }/events?${params}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );

  if (response.status === 410) {
    // Sync token scaduto/non valido: si azzera, la prossima esecuzione riparte con
    // timeMin invece di un syncToken (stesso comportamento di una prima pull).
    await supabase
      .from("calendar_connections")
      .update({ sync_token: null })
      .eq("user_id", connection.user_id);
    return;
  }
  if (!response.ok) {
    console.error(
      "pull-google-calendar-events: events.list fallita",
      connection.user_id,
      response.status,
      await response.text(),
    );
    return;
  }

  const body = await response.json();
  const items = Array.isArray(body?.items) ? body.items : [];

  const { data: appuntamentiWorkspace } = await supabase
    .from("workspaces")
    .select("id")
    .eq("owner_id", connection.user_id)
    .eq("category", "appuntamenti")
    .maybeSingle();

  if (items.length > 0 && appuntamentiWorkspace) {
    for (const item of items) {
      await applyGoogleEvent(
        supabase,
        appuntamentiWorkspace.id as string,
        item,
      );
    }
  }

  await supabase
    .from("calendar_connections")
    .update({
      sync_token: typeof body?.nextSyncToken === "string"
        ? body.nextSyncToken
        : null,
      last_synced_at: new Date().toISOString(),
    })
    .eq("user_id", connection.user_id);
}

async function applyGoogleEvent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  workspaceId: string,
  // deno-lint-ignore no-explicit-any
  item: any,
): Promise<void> {
  const googleEventId = item.id as string | undefined;
  if (!googleEventId) return;

  const { data: existing } = await supabase
    .from("calendar_events")
    .select("id")
    .eq("google_event_id", googleEventId)
    .maybeSingle();

  if (item.status === "cancelled") {
    if (existing) {
      await supabase
        .from("calendar_events")
        .update({ deleted_at: new Date().toISOString() })
        .eq("id", existing.id);
    }
    return;
  }

  // Già presente localmente: nessun updateEvent esposto oggi lato client (vedi
  // packages/domain, CalendarEventRepository) — un evento già collegato non viene
  // aggiornato qui per restare coerenti con quel limite, solo creato se mancante.
  if (existing) return;

  const startIso = item.start?.dateTime ?? item.start?.date;
  const endIso = item.end?.dateTime ?? item.end?.date;
  const title = typeof item.summary === "string" && item.summary.trim() !== ""
    ? item.summary
    : "(senza titolo)";
  if (!startIso) return;

  const startsAt = new Date(startIso);
  const durationMinutes = endIso
    ? Math.max(
      1,
      Math.round((new Date(endIso).getTime() - startsAt.getTime()) / 60000),
    )
    : 30;

  await supabase.from("calendar_events").insert({
    workspace_id: workspaceId,
    title,
    starts_at: startsAt.toISOString(),
    duration_minutes: durationMinutes,
    google_event_id: googleEventId,
  });
}

async function getGoogleAccessToken(
  refreshToken: string,
  clientId: string,
  clientSecret: string,
): Promise<string | null> {
  try {
    const response = await fetch(GOOGLE_TOKEN_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: "refresh_token",
      }),
    });
    if (!response.ok) {
      console.error(
        "getGoogleAccessToken: refresh fallito",
        response.status,
        await response.text(),
      );
      return null;
    }
    const data = await response.json();
    return typeof data?.access_token === "string" ? data.access_token : null;
  } catch (error) {
    console.error("getGoogleAccessToken: errore inatteso", error);
    return null;
  }
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
