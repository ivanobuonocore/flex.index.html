// Salva il refresh token OAuth restituito da Supabase Auth subito dopo
// `auth.linkIdentity(OAuthProvider.google, ...)` (Fase 3, "Sync con Google Calendar" —
// integrazione richiesta esplicitamente). Supabase espone `provider_refresh_token` nella
// sessione solo nel primo evento subito dopo il collegamento, mai persistito lato client:
// questa function lo riceve una volta e lo scrive sotto RLS in `calendar_connections`, da
// cui poi lo leggono `sync-calendar-event`/`pull-google-calendar-events`.
//
// Usa sempre il JWT di chi chiama, mai la service role: le RLS di `calendar_connections`
// (`infrastructure/supabase/migrations/20260723170000_google_calendar_sync.sql`) si
// applicano identiche qui dentro — questa function non ha alcun modo di scrivere la riga
// di un utente diverso da chi chiama.

import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
    const refreshToken = typeof body?.refreshToken === "string"
      ? body.refreshToken
      : null;
    if (!refreshToken) {
      return jsonError("refreshToken obbligatorio.", 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      console.error(
        "save-calendar-connection: variabili d'ambiente mancanti (SUPABASE_URL/ANON_KEY)",
      );
      return jsonError("Servizio non configurato.", 500);
    }

    // Client con il JWT dell'utente: la scrittura sotto è soggetta a RLS esattamente
    // come se la facesse l'app mobile.
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData?.user) {
      return jsonError("Sessione non valida.", 401);
    }

    const { error } = await supabase.from("calendar_connections").upsert(
      {
        user_id: userData.user.id,
        google_refresh_token: refreshToken,
        google_calendar_id: "primary",
      },
      { onConflict: "user_id" },
    );

    if (error) {
      console.error("save-calendar-connection: errore upsert", error);
      return jsonError("Non è stato possibile salvare il collegamento.", 500);
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...CORS_HEADERS, "content-type": "application/json" },
    });
  } catch (error) {
    console.error("save-calendar-connection: errore inatteso", error);
    return jsonError("Si è verificato un problema. Riprova.", 500);
  }
});

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}
