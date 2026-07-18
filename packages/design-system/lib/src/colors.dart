import 'package:flutter/widgets.dart';

/// Palette (docs/product/05-design-system.md, versione "aggiornata rispetto
/// al Capitolo 3" — fonte di verità finché la nota di consolidamento nel
/// documento non viene risolta).
abstract final class AppColors {
  // Light mode
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color secondaryLight = Color(0xFF7C3AED);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // Dark mode
  static const Color backgroundDark = Color(0xFF111827);
  static const Color cardDark = Color(0xFF1F2937);
  static const Color primaryDark = Color(0xFF60A5FA);
  static const Color secondaryDark = Color(0xFFA78BFA);
  static const Color textPrimaryDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Stati semantici, comuni a light e dark mode.
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}
