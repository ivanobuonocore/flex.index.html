import 'package:flutter/widgets.dart';

/// Ombre leggere e diffuse (docs/product/05-design-system.md, "Ombre" —
/// "l'interfaccia deve sembrare leggera").
abstract final class AppShadows {
  /// Livello più basso della gerarchia (redesign estetico — "gerarchia
  /// visiva a più livelli invece di un'unica ombra piatta"): per superfici
  /// "a livello lista" — `Card` standard di Note/Attività/Documenti/
  /// Promemoria, tile di riepilogo — dove serve solo un accenno di
  /// sollevamento dallo sfondo, non il rilievo più marcato di [card].
  static List<BoxShadow> subtle({required bool isDark}) => [
        BoxShadow(
          color: (isDark ? const Color(0xFF000000) : const Color(0xFF111827))
              .withOpacity(isDark ? 0.16 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

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
}
