import 'package:flutter/material.dart';

import 'colors.dart';
import 'radii.dart';
import 'typography.dart';

/// Temi Material derivati dai token del Design System. Le feature devono
/// sempre leggere gli stili da `Theme.of(context)`, mai istanziare colori o
/// `TextStyle` propri (AGENTS.md, "Design System").
abstract final class AppTheme {
  static ThemeData light() => _build(brightness: Brightness.light);
  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColors.primaryDark : AppColors.primaryLight,
      onPrimary: isDark ? AppColors.backgroundDark : Colors.white,
      secondary: isDark ? AppColors.secondaryDark : AppColors.secondaryLight,
      onSecondary: isDark ? AppColors.backgroundDark : Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: isDark ? AppColors.cardDark : AppColors.cardLight,
      onSurface:
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    );

    final textTheme = TextTheme(
      displayLarge: AppTypography.display,
      headlineLarge: AppTypography.heading1,
      headlineMedium: AppTypography.heading2,
      headlineSmall: AppTypography.heading3,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.caption,
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      textTheme: textTheme,
      // Prima piatta (elevation: 0, nessuna ombra): ogni `Card` standard
      // (liste di Note/Attività/Documenti/Promemoria, tile di riepilogo)
      // risultava indistinguibile dallo sfondo salvo per gli angoli
      // arrotondati. Un'elevazione minima con un'ombra neutra e stretta
      // basta a farla percepire come una superficie sollevata (stessa
      // gerarchia di `AppShadows.subtle`, qui espressa con l'elevazione
      // Material perché `CardTheme` non accetta un `BoxShadow` custom),
      // senza il rilievo marcato riservato agli elementi "hero"
      // (`AppShadows.glow`). `surfaceTintColor: transparent` disattiva la
      // tinta blu automatica di Material 3 sulle superfici elevate: qui la
      // profondità è data solo dall'ombra, non da un lavaggio di colore che
      // altererebbe il bianco/nero della card.
      cardTheme: CardTheme(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1.5,
        shadowColor: isDark ? Colors.black : const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.standardRadius),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          animationDuration: AppMotion.fast,
          elevation: 1,
          disabledElevation: 0,
        ),
      ),
      // Stessa forma dell'`ElevatedButton` (redesign estetico — coerenza:
      // prima gli `OutlinedButton`/`TextButton` prendevano la forma "a
      // pillola" di default di Material 3, diversa dal rettangolo
      // arrotondato del bottone pieno, un dettaglio che tradisce
      // un'interfaccia "di template" più che disegnata).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          animationDuration: AppMotion.fast,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius),
          animationDuration: AppMotion.fast,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
      // Dialoghi/bottom sheet condividevano solo il colore di sfondo di
      // default Material — nessun raggio/ombra coerente col resto del
      // Design System (redesign estetico).
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: isDark ? Colors.black : const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardPremiumRadius),
      ),
      // `showDragHandle`/`dragHandleColor` di default: prima solo 6 sheet su
      // 17 lo impostavano esplicitamente, gli altri comparivano senza alcun
      // indizio visivo di trascinabilità (redesign estetico — coerenza).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalElevation: 8,
        shadowColor: isDark ? Colors.black : const Color(0xFF111827),
        showDragHandle: true,
        dragHandleColor: (isDark ? Colors.white : Colors.black)
            .withOpacity(isDark ? 0.24 : 0.16),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.cardPremium)),
        ),
      ),
      // `StadiumBorder` esplicito invece dello shape di default (che in
      // Material 3 dipende dal tema Chip generico): coerente con
      // `AppRadii.pillRadius`, la stessa "pillola" già usata altrove nel
      // redesign per badge/tag.
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary.withOpacity(isDark ? 0.28 : 0.12),
        labelStyle:
            AppTypography.caption.copyWith(color: colorScheme.onSurface),
        side: BorderSide(
            color: isDark ? AppColors.hairlineDark : AppColors.hairlineLight),
        shape: const StadiumBorder(),
      ),
      // `SnackBarBehavior.floating` invece della barra piena larghezza di
      // default (redesign estetico — stile Apple/Linear: una notifica
      // "sospesa" invece di una barra che sembra parte della struttura).
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.standardRadius),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: AppMotion.fast,
        showDuration: const Duration(seconds: 2),
      ),
      // Nessuna ombra/tinta al passaggio dello scroll sotto l'AppBar
      // (redesign estetico): coerente con `GradientAppBar`, che gestisce la
      // propria profondità con `AppShadows.glow` sul contenitore esterno,
      // non con l'elevazione automatica di Material.
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.hairlineDark : AppColors.hairlineLight,
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _PipPageTransitionsBuilder(),
          TargetPlatform.iOS: _PipPageTransitionsBuilder(),
          TargetPlatform.macOS: _PipPageTransitionsBuilder(),
          TargetPlatform.windows: _PipPageTransitionsBuilder(),
          TargetPlatform.linux: _PipPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _PipPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Cambio schermata breve, senza spostare la struttura: dissolve e sale di
/// pochi pixel, con rispetto automatico della preferenza riduci movimento.
class _PipPageTransitionsBuilder extends PageTransitionsBuilder {
  const _PipPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.of(context).disableAnimations) return child;

    final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
