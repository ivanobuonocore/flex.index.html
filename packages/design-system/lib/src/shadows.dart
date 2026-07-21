import 'package:flutter/widgets.dart';

import 'colors.dart';

/// Ombre leggere e diffuse (docs/product/05-design-system.md, "Ombre" —
/// "l'interfaccia deve sembrare leggera").
abstract final class AppShadows {
  static List<BoxShadow> card({required bool isDark}) => [
        BoxShadow(
          color: (isDark ? const Color(0xFF000000) : const Color(0xFF111827))
              .withOpacity(isDark ? 0.24 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Alone colorato più profondo, in aggiunta all'ombra neutra di [card]
  /// (redesign estetico 2.0 — richiesta esplicita dell'utente: "profondità",
  /// "molto tecnologica"): per superfici "hero" in primo piano (es. il saldo
  /// nel Bilancio, l'header della Chat), non per ogni Card — usarla ovunque
  /// annullerebbe l'effetto di rilievo che dà a un singolo elemento.
  /// `spreadRadius` negativo: l'alone resta morbido e diffuso invece di un
  /// bordo colorato netto attorno al contenitore.
  static List<BoxShadow> glow({required Color color, required bool isDark}) => [
        ...card(isDark: isDark),
        BoxShadow(
          color: color.withOpacity(isDark ? 0.35 : 0.25),
          blurRadius: 40,
          offset: const Offset(0, 16),
          spreadRadius: -8,
        ),
      ];

  /// Come [glow], ma con più colori insieme (stessa famiglia di
  /// [AppColors.siriGlow]) invece di uno solo — richiesta esplicita
  /// dell'utente: "i colori che stai usando stile Siri" per il grafico del
  /// Bilancio. Un solo alone per colore, sovrapposti: risultato più ricco di
  /// [glow] senza introdurre una tecnica di rendering diversa.
  static List<BoxShadow> siriGlow({required bool isDark}) => [
        ...card(isDark: isDark),
        for (final color in AppColors.siriGlow)
          BoxShadow(
            color: color.withOpacity(
                (isDark ? 0.30 : 0.20) / AppColors.siriGlow.length * 2),
            blurRadius: 36,
            offset: const Offset(0, 12),
            spreadRadius: -10,
          ),
      ];
}
