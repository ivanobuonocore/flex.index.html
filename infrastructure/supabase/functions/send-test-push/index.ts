// Invia una notifica push di prova alle iscrizioni Web Push dell'utente che chiama
// (CLAUDE.md, "Notifiche push vere" — prima slice: infrastruttura + prova). Stesso
// principio delle altre Edge Function del progetto: usa sempre il JWT di chi chiama,
// mai la service role — le RLS di `push_subscriptions` (solo le proprie righe) si
// applicano identiche qui dentro.
//
// Non fa parte dell'AI Engine (nessuna chiamata ad Anthropic): è infrastruttura di
// consegna, isolata in una function a sé perché non ha nulla a che fare con la Chat.

import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const NOTIFICATION_PAYLOAD = JSON.stringify({
  title: "PIP",
  body: "Le notifiche funzionano! Questa è una notifica di prova.",
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Autenticazione mancante.", 401);
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
        "send-test-push: variabili d'ambiente mancanti (SUPABASE_URL/ANON_KEY/VAPID_*)",
      );
      return jsonError("Servizio notifiche non configurato.", 500);
    }

    // Client con il JWT dell'utente: la select qui sotto è soggetta a RLS esattamente
    // come se la facesse l'app mobile — legge solo le iscrizioni dell'utente stesso.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: subscriptions, error: readError } = await supabase
      .from("push_subscriptions")
      .select("id, endpoint, p256dh, auth_key");

    if (readError) {
      console.error(
        "send-test-push: errore lettura push_subscriptions",
        readError,
      );
      return jsonError("Non è stato possibile leggere le iscrizioni.", 500);
    }

    if (!subscriptions || subscriptions.length === 0) {
      return jsonError("Nessuna iscrizione alle notifiche trovata.", 404);
    }

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
          NOTIFICATION_PAYLOAD,
        );
        sent += 1;
      } catch (error) {
        const statusCode = (error as { statusCode?: number }).statusCode;
        if (statusCode === 404 || statusCode === 410) {
          // Iscrizione scaduta/revocata lato browser: pulizia silenziosa, non un
          // errore da mostrare all'utente.
          expiredIds.push(sub.id as string);
        } else {
          console.error("send-test-push: invio fallito", error);
        }
      }
    }

    if (expiredIds.length > 0) {
      await supabase.from("push_subscriptions").delete().in("id", expiredIds);
    }

    if (sent === 0) {
      return jsonError(
        "Nessuna notifica inviata: le iscrizioni trovate risultano scadute.",
        410,
      );
    }

    return new Response(JSON.stringify({ ok: true, sent }), {
      status: 200,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (error) {
    console.error("send-test-push: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
