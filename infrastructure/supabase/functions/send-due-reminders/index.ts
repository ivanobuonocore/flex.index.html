// Invia le notifiche push dei Promemoria scaduti (Fase 3, "Promemoria via Chat" —
// CLAUDE.md, richiesta esplicita dell'utente: notifiche di sistema vere, non un
// semplice elenco in app). Invocata da un cron job Postgres (`pg_cron`, ogni minuto —
// vedi infrastructure/supabase/migrations/20260722090000_calendar_events.sql), non da
// una richiesta di un utente autenticato: non esiste un JWT da inoltrare.
//
// A differenza di ai-chat e send-test-push, questa è l'UNICA function del progetto che
// usa la service role, non il JWT di chi chiama — giustificato esplicitamente: deve
// leggere calendar_events di TUTTI gli utenti (per trovare i promemoria scaduti), non
// solo quelli di uno specifico chiamante. Le RLS di calendar_events/push_subscriptions
// restano intatte per ogni altro accesso (client mobile, ai-chat) — qui vengono
// bypassate by design, non aggirate per errore.

import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

// Limite prudenziale sulla finestra di lettura, non sul momento effettivo dell'invio
// (calcolato riga per riga più sotto): evita di scandire l'intera tabella ad ogni
// esecuzione (il cron gira ogni minuto), leggendo solo ciò che potrebbe essere dovuto
// entro le prossime 24 ore anche col preavviso più lungo configurato.
const LOOKAHEAD_HOURS = 24;

Deno.serve(async (req) => {
  // Nessun CORS/OPTIONS: questa function non viene mai chiamata da un browser, solo
  // dal cron job Postgres via pg_net (server-to-server).
  if (req.method !== "POST") {
    return jsonError("Metodo non supportato.", 405);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
    const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
    const vapidSubject = Deno.env.get("VAPID_SUBJECT");

    if (
      !supabaseUrl || !serviceRoleKey || !vapidPublicKey || !vapidPrivateKey ||
      !vapidSubject
    ) {
      console.error(
        "send-due-reminders: variabili d'ambiente mancanti " +
          "(SUPABASE_URL/SERVICE_ROLE_KEY/VAPID_*)",
      );
      return jsonError("Servizio promemoria non configurato.", 500);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const now = new Date();
    const lookaheadIso = new Date(
      now.getTime() + LOOKAHEAD_HOURS * 60 * 60 * 1000,
    ).toISOString();

    const { data: candidates, error: candidatesError } = await supabase
      .from("calendar_events")
      .select("id, workspace_id, title, starts_at, reminder_minutes_before")
      .is("notified_at", null)
      .is("deleted_at", null)
      .lte("starts_at", lookaheadIso);

    if (candidatesError) {
      console.error(
        "send-due-reminders: errore lettura calendar_events",
        candidatesError,
      );
      return jsonError("Non è stato possibile leggere i promemoria.", 500);
    }

    // Il momento effettivo dell'invio è starts_at meno l'eventuale preavviso, non
    // starts_at stesso: LOOKAHEAD_HOURS sopra è solo un limite sulla lettura, il
    // filtro vero è qui, riga per riga.
    const due = (candidates ?? []).filter((event) => {
      const startsAt = new Date(event.starts_at as string).getTime();
      const reminderMs = ((event.reminder_minutes_before as number | null) ?? 0) *
        60 * 1000;
      return startsAt - reminderMs <= now.getTime();
    });

    if (due.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    const workspaceIds = [...new Set(due.map((e) => e.workspace_id as string))];
    const { data: workspaces, error: workspacesError } = await supabase
      .from("workspaces")
      .select("id, owner_id")
      .in("id", workspaceIds);

    if (workspacesError) {
      console.error(
        "send-due-reminders: errore lettura workspaces",
        workspacesError,
      );
      return jsonError("Non è stato possibile risalire ai proprietari.", 500);
    }

    const ownerByWorkspace = new Map<string, string>(
      (workspaces ?? []).map((w) => [w.id as string, w.owner_id as string]),
    );
    const ownerIds = [...new Set(ownerByWorkspace.values())];

    const { data: subscriptions, error: subscriptionsError } = await supabase
      .from("push_subscriptions")
      .select("id, user_id, endpoint, p256dh, auth_key")
      .in("user_id", ownerIds);

    if (subscriptionsError) {
      console.error(
        "send-due-reminders: errore lettura push_subscriptions",
        subscriptionsError,
      );
      return jsonError("Non è stato possibile leggere le iscrizioni.", 500);
    }

    const subscriptionsByOwner = new Map<
      string,
      { id: string; endpoint: string; p256dh: string; auth_key: string }[]
    >();
    for (const sub of subscriptions ?? []) {
      const list = subscriptionsByOwner.get(sub.user_id as string) ?? [];
      list.push(sub);
      subscriptionsByOwner.set(sub.user_id as string, list);
    }

    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

    let sent = 0;
    const expiredSubscriptionIds: string[] = [];
    const notifiedEventIds: string[] = [];

    for (const event of due) {
      const ownerId = ownerByWorkspace.get(event.workspace_id as string);
      const ownerSubscriptions = ownerId
        ? subscriptionsByOwner.get(ownerId) ?? []
        : [];

      const payload = JSON.stringify({
        title: "Promemoria",
        body: event.title as string,
      });

      for (const sub of ownerSubscriptions) {
        try {
          await webpush.sendNotification(
            {
              endpoint: sub.endpoint,
              keys: { p256dh: sub.p256dh, auth: sub.auth_key },
            },
            payload,
          );
          sent += 1;
        } catch (error) {
          const statusCode = (error as { statusCode?: number }).statusCode;
          if (statusCode === 404 || statusCode === 410) {
            expiredSubscriptionIds.push(sub.id);
          } else {
            console.error(
              "send-due-reminders: invio fallito",
              event.id,
              error,
            );
          }
        }
      }

      // Marcato "notificato" indipendentemente dal numero di iscrizioni raggiunte
      // con successo (anche zero, es. proprietario senza alcuna iscrizione attiva):
      // il cron gira ogni minuto, e un promemoria orario non deve essere ritentato
      // indefinitamente né consegnato in ritardo una volta risolto un problema di
      // iscrizione — coerente con la natura "one-shot" di un avviso a tempo.
      notifiedEventIds.push(event.id as string);
    }

    if (expiredSubscriptionIds.length > 0) {
      await supabase.from("push_subscriptions").delete().in(
        "id",
        expiredSubscriptionIds,
      );
    }

    if (notifiedEventIds.length > 0) {
      await supabase.from("calendar_events").update({
        notified_at: new Date().toISOString(),
      }).in("id", notifiedEventIds);
    }

    return new Response(
      JSON.stringify({ ok: true, sent, events: notifiedEventIds.length }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (error) {
    console.error("send-due-reminders: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { "content-type": "application/json" },
  });
}
