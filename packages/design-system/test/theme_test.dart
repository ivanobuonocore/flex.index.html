import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_design_system/pip_design_system.dart';

void main() {
  group('AppTheme', () {
    test('light() usa la palette light mode', () {
      final theme = AppTheme.light();

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.primaryLight);
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('dark() usa la palette dark mode', () {
      final theme = AppTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.primaryDark);
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundDark);
    });
  });
}
