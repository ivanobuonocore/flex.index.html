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
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 0,
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
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
