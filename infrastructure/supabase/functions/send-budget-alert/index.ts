// Notifica push quando la spesa di una categoria si avvicina o supera il budget mensile
// impostato dall'utente (integrazione richiesta esplicitamente, dopo "Budget per categoria" —
// docs/database/README.md, slice 18). Stesso principio delle altre Edge Function del progetto:
// usa sempre il JWT di chi chiama, mai la service role — le RLS di `category_budgets`/
// `push_subscriptions` (solo le proprie righe) si applicano identiche qui dentro.
//
// Chiamata direttamente dal client subito dopo aver confermato/creato una Transazione di spesa
// (pattern di `send-test-push`, non il cron di `send-due-reminders`): l'evento è deterministico al
// momento della conferma, non serve una scansione periodica su tutti gli utenti.

import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const CATEGORY_LABELS: Record<string, string> = {
  alimentari: "Alimentari",
  trasporti: "Trasporti",
  casa: "Casa",
  bollette: "Bollette",
  salute: "Salute",
  svago: "Svago",
  shopping: "Shopping",
  istruzione: "Istruzione",
  stipendio: "Stipendio",
  altro: "Altro",
};

// Soglie fisse (non configurabili dall'utente in questa slice, come le altre notifiche del
// progetto): l'80% avvisa in anticipo, il 100% conferma il superamento.
const THRESHOLDS = [100, 80] as const;

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
    const budgetId = typeof body?.budgetId === "string" ? body.budgetId : null;
    const category = typeof body?.category === "string" ? body.category : null;
    const spentCents = typeof body?.spentCents === "number"
      ? body.spentCents
      : null;
    const limitCents = typeof body?.limitCents === "number"
      ? body.limitCents
      : null;

    if (
      !budgetId || !category || spentCents === null || limitCents === null ||
      limitCents <= 0
    ) {
      return jsonError("Parametri mancanti o non validi.", 400);
    }

    const crossedThreshold = THRESHOLDS.find((t) =>
      spentCents >= limitCents * (t / 100)
    );
    if (crossedThreshold === undefined) {
      // Nessuna soglia superata: nessuna notifica da inviare, non è un errore.
      return new Response(JSON.stringify({ ok: true, sent: false }), {
        status: 200,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
    const vapidPrivateKey = Deno.env.get("VAPID_PRIVATE_KEY");
    const vapidSubject = Deno.env.get("VAPID_SUBJECT");

    if (
      !supabaseUrl || !supabaseAnonKey || !vapidPublicKey ||
      !vapidPrivateKey || !vapidSubject
    ) {
      console.error(
        "send-budget-alert: variabili d'ambiente mancanti (SUPABASE_URL/ANON_KEY/VAPID_*)",
      );
      return jsonError("Servizio notifiche non configurato.", 500);
    }

    // Client con il JWT dell'utente: sia la lettura di category_budgets/push_subscriptions sia
    // l'update qui sotto restano soggetti a RLS, esattamente come se li facesse l'app mobile.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: budgetRow, error: budgetError } = await supabase
      .from("category_budgets")
      .select("last_alert_threshold, last_alert_month")
      .eq("id", budgetId)
      .single();

    if (budgetError) {
      console.error(
        "send-budget-alert: errore lettura category_budgets",
        budgetError,
      );
      return jsonError("Non è stato possibile leggere il budget.", 500);
    }

    // Mese corrente in UTC (YYYY-MM): un mese diverso da quello dell'ultima notifica equivale a
    // "nessuna soglia ancora notificata questo mese", senza bisogno di un reset esplicito.
    const currentMonth = new Date().toISOString().slice(0, 7);
    const alreadyNotified = budgetRow.last_alert_month === currentMonth &&
      typeof budgetRow.last_alert_threshold === "number" &&
      budgetRow.last_alert_threshold >= crossedThreshold;

    if (alreadyNotified) {
      return new Response(JSON.stringify({ ok: true, sent: false }), {
        status: 200,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const { data: subscriptions, error: readError } = await supabase
      .from("push_subscriptions")
      .select("id, endpoint, p256dh, auth_key");

    if (readError) {
      console.error(
        "send-budget-alert: errore lettura push_subscriptions",
        readError,
      );
      return jsonError("Non è stato possibile leggere le iscrizioni.", 500);
    }

    // Aggiorna comunque lo stato di notifica anche senza iscrizioni push attive: evita di
    // ritentare a ogni transazione se l'utente non ha mai attivato le notifiche.
    await supabase
      .from("category_budgets")
      .update({
        last_alert_threshold: crossedThreshold,
        last_alert_month: currentMonth,
      })
      .eq("id", budgetId);

    if (!subscriptions || subscriptions.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: false }), {
        status: 200,
        headers: { ...CORS_HEADERS, "content-type": "application/json" },
      });
    }

    const label = CATEGORY_LABELS[category] ?? category;
    const payload = JSON.stringify({
      title: "PIP",
      body: crossedThreshold >= 100
        ? `Hai superato il budget mensile per ${label}.`
        : `Hai superato l'80% del budget mensile per ${label}.`,
    });

    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

    let sent = 0;
    const expiredIds: string[] = [];

    for (const sub of subscriptions) {
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
          expiredIds.push(sub.id as string);
        } else {
          console.error("send-budget-alert: invio fallito", error);
        }
      }
    }

    if (expiredIds.length > 0) {
      await supabase.from("push_subscriptions").delete().in("id", expiredIds);
    }

    return new Response(JSON.stringify({ ok: true, sent: sent > 0 }), {
      status: 200,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (error) {
    console.error("send-budget-alert: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
