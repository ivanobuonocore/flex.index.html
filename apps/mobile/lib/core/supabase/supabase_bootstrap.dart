import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/app_env.dart';

/// Inizializza il client Supabase. Va chiamato una sola volta, prima di
/// `runApp` (vedi `main.dart`).
Future<void> bootstrapSupabase() async {
  AppEnv.assertConfigured();
  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    // SUPABASE_ANON_KEY resta il nome della variabile d'ambiente (è così che
    // Supabase la mostra nella dashboard); il parametro `publishableKey`
    // sostituisce `anonKey`, deprecato in supabase_flutter.
    publishableKey: AppEnv.supabaseAnonKey,
  );
}

/// Punto di accesso condiviso al client Supabase già inizializzato.
SupabaseClient get supabaseClient => Supabase.instance.client;
