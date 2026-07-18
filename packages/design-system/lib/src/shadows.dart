import 'package:flutter/widgets.dart';

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
}
