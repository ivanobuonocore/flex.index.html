import 'package:flutter/animation.dart';

/// Durate e curve delle animazioni (docs/product/05-design-system.md,
/// "Animazioni" — 180–250ms, curve morbide).
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 250);
  static const Curve curve = Curves.easeInOutCubic;

  /// Curva "emphasized" (accelerazione dolce, decelerazione più marcata in
  /// coda — stile Apple/Material 3), in aggiunta a [curve]: per pressioni e
  /// transizioni di pagina del redesign estetico. Non sostituisce [curve],
  /// già usata da animazioni implicite esistenti e verificate visivamente.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
}
