/// Configurazione d'ambiente iniettata a build time, mai hardcoded
/// (AI Engineering Playbook, "Sicurezza" — nessuna chiave nel codice sorgente).
///
/// Uso: `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
/// La anon key di Supabase è progettata per essere pubblica: l'isolamento dei
/// dati è garantito dalle policy RLS (`infrastructure/supabase/migrations`),
/// non dalla segretezza della chiave.
abstract final class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Chiave pubblica VAPID (Web Push, RFC 8291) — non è segreta: viene comunque
  /// inviata al browser per `pushManager.subscribe()`, a differenza della chiave
  /// privata (mai nel client, resta solo nei secrets della Edge Function
  /// `send-test-push`). Facoltativa: l'app deve restare utilizzabile anche senza,
  /// semplicemente senza il pulsante "Attiva notifiche" in Profilo.
  static const String vapidPublicKey =
      String.fromEnvironment('VAPID_PUBLIC_KEY');

  /// `true` solo se chi compila l'app ha già abilitato il provider Google nel
  /// dashboard Supabase (Authentication → Providers, con lo scope Calendar) e
  /// creato un OAuth Client su Google Cloud Console — passi manuali fuori dal
  /// codice, vedi `infrastructure/supabase/README.md`. Nessun segreto qui
  /// dentro (a differenza di VAPID non serve alcun valore al client, solo un
  /// interruttore): nascondere il pulsante "Connetti Google Calendar" finché
  /// non è vero evita di mostrare un'azione che fallirebbe sempre.
  static const bool googleCalendarEnabled =
      bool.fromEnvironment('GOOGLE_CALENDAR_ENABLED');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL e SUPABASE_ANON_KEY sono obbligatorie. '
        'Avvia con --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
        '(vedi infrastructure/supabase/README.md).',
      );
    }
  }
}
