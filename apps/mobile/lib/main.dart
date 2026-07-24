import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pip_design_system/pip_design_system.dart';
import 'package:pip_domain/pip_domain.dart';

import 'core/router/app_router.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/auth/application/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapSupabase();
  runApp(const ProviderScope(child: PipApp()));
}

class PipApp extends ConsumerWidget {
  const PipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Preferenza di tema dell'utente (richiesta esplicita: "tema chiaro/
    // scuro"), `system` finché non c'è una sessione (schermata di login) o
    // finché l'utente non ha mai scelto — stesso comportamento di prima di
    // questa slice.
    final appThemeMode =
        ref.watch(sessionControllerProvider).value?.themeMode ??
            AppThemeMode.system;

    return MaterialApp.router(
      title: 'PIP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _toFlutterThemeMode(appThemeMode),
      // Il passaggio chiaro/scuro dissolve i token del tema invece di
      // cambiare fotogramma all'improvviso. Durata e curva fanno parte del
      // sistema centralizzato di movimento.
      themeAnimationDuration: AppMotion.slow,
      themeAnimationCurve: AppMotion.curve,
      routerConfig: router,
    );
  }

  ThemeMode _toFlutterThemeMode(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };
}
