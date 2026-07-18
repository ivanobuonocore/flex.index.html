import 'package:flutter/animation.dart';

/// Durate e curve delle animazioni (docs/product/05-design-system.md,
/// "Animazioni" — 180–250ms, curve morbide).
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 250);
  static const Curve curve = Curves.easeInOutCubic;
}
