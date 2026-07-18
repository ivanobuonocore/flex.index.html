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
