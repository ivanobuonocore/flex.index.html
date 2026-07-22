// Sincronizza un Promemoria (calendar_events) su Google Calendar, subito dopo che è stato
// creato o cancellato in apps/mobile (Fase 3, "Sync con Google Calendar" — integrazione
// richiesta esplicitamente). Stesso pattern di `send-test-push`/`send-budget-alert`: chiamata
// diretta dal client col proprio JWT, non un cron — l'evento ("questo Promemoria va creato/
// cancellato su Google") è deterministico nel momento della mutazione locale, non richiede una
// scansione periodica.
//
// Best-effort per il chiamante: se l'utente non ha collegato un account Google, o Google non è
// raggiungibile, ritorna `{ ok: true, synced: false }` — mai un errore che a apps/mobile
// impedirebbe di considerare già riuscita la create/delete locale (BudgetRepository.
// checkBudgetAlert nella stessa sessione di lavoro adotta lo stesso principio).
//
// Usa sempre il JWT di chi chiama, mai la service role: le RLS di calendar_events/
// calendar_connections si applicano identiche qui dentro.

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const GOOGLE_CALENDAR_API = "https://www.googleapis.com/calendar/v3";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Autenticazione mancante.", 401);
    }

    const body = await req.json().catch(() => null);
    const eventId = typeof body?.eventId === "string" ? body.eventId : null;
    const deleted = body?.deleted === true;
    if (!eventId) {
      return jsonError("eventId obbligatorio.", 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const googleClientId = Deno.env.get("GOOGLE_CLIENT_ID");
    const googleClientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET");

    if (
      !supabaseUrl || !supabaseAnonKey || !googleClientId || !googleClientSecret
    ) {
      console.error(
        "sync-calendar-event: variabili d'ambiente mancanti " +
          "(SUPABASE_URL/ANON_KEY/GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET)",
      );
      return jsonError("Servizio non configurato.", 500);
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: connection, error: connectionError } = await supabase
      .from("calendar_connections")
      .select("google_refresh_token, google_calendar_id")
      .maybeSingle();

    if (connectionError) {
      console.error(
        "sync-calendar-event: errore lettura calendar_connections",
        connectionError,
      );
      return jsonError("Non è stato possibile leggere il collegamento.", 500);
    }
    if (!connection) {
      // Nessun account Google collegato: non è un errore, semplicemente non c'è nulla da
      // sincronizzare — vedi il commento in testa al file.
      return jsonResult(false);
    }

    const { data: event, error: eventError } = await supabase
      .from("calendar_events")
      .select("title, starts_at, duration_minutes, google_event_id")
      .eq("id", eventId)
      .maybeSingle();

    if (eventError) {
      console.error(
        "sync-calendar-event: errore lettura calendar_events",
        eventError,
      );
      return jsonError("Non è stato possibile leggere il promemoria.", 500);
    }
    if (!event) {
      return jsonResult(false);
    }

    const accessToken = await getGoogleAccessToken(
      connection.google_refresh_token as string,
      googleClientId,
      googleClientSecret,
    );
    if (!accessToken) {
      console.error(
        "sync-calendar-event: impossibile ottenere un access token Google",
      );
      return jsonResult(false);
    }

    const calendarId = (connection.google_calendar_id as string) || "primary";

    if (deleted) {
      const googleEventId = event.google_event_id as string | null;
      if (!googleEventId) {
        // Mai sincronizzato su Google: nulla da cancellare lì.
        return jsonResult(false);
      }
      const response = await fetch(
        `${GOOGLE_CALENDAR_API}/calendars/${
          encodeURIComponent(calendarId)
        }/events/${encodeURIComponent(googleEventId)}`,
        {
          method: "DELETE",
          headers: { Authorization: `Bearer ${accessToken}` },
        },
      );
      // 404/410 = già cancellato/mai esistito su Google: non è un fallimento della
      // sincronizzazione, l'obiettivo (l'evento non esiste più su Google) è già vero.
      if (!response.ok && response.status !== 404 && response.status !== 410) {
        console.error(
          "sync-calendar-event: cancellazione Google fallita",
          response.status,
          await response.text(),
        );
        return jsonResult(false);
      }
      return jsonResult(true);
    }

    if (event.google_event_id) {
      // Già sincronizzato: nessun metodo di modifica esposto oggi lato client
      // (CalendarEventRepository non ha un updateEvent — vedi packages/domain), quindi un
      // evento già collegato non ha nulla in più da inviare qui.
      return jsonResult(false);
    }

    const startsAt = new Date(event.starts_at as string);
    const endsAt = new Date(
      startsAt.getTime() + (event.duration_minutes as number) * 60 * 1000,
    );

    const insertResponse = await fetch(
      `${GOOGLE_CALENDAR_API}/calendars/${
        encodeURIComponent(calendarId)
      }/events`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          summary: event.title,
          start: { dateTime: startsAt.toISOString() },
          end: { dateTime: endsAt.toISOString() },
        }),
      },
    );

    if (!insertResponse.ok) {
      console.error(
        "sync-calendar-event: creazione Google fallita",
        insertResponse.status,
        await insertResponse.text(),
      );
      return jsonResult(false);
    }

    const inserted = await insertResponse.json();
    const googleEventId = inserted?.id as string | undefined;
    if (googleEventId) {
      await supabase
        .from("calendar_events")
        .update({ google_event_id: googleEventId })
        .eq("id", eventId);
    }

    return jsonResult(true);
  } catch (error) {
    console.error("sync-calendar-event: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

// Scambia il refresh token per un access token valido (scade dopo circa un'ora, mai
// riutilizzato oltre la singola chiamata) — stesso endpoint OAuth usato da
// pull-google-calendar-events, duplicato invece di condiviso: nessuna convenzione di
// modulo condiviso tra le Edge Function in questo progetto (coerente con la scelta già
// fatta altrove di duplicare piuttosto che introdurre una dipendenza tra function).
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

function jsonResult(synced: boolean): Response {
  return new Response(JSON.stringify({ ok: true, synced }), {
    status: 200,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
