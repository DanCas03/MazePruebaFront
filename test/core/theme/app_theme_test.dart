import 'package:flutter/material.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme.dark', () {
    test('uses the dark neutral near-black scaffold background', () {
      // Arrange + Act
      final theme = AppTheme.dark();

      // Assert
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.useMaterial3, isTrue);
    });
  });

  group('AppTheme.light', () {
    test('uses the frosted-on-light scaffold background and deepened accents',
        () {
      // Arrange + Act
      final theme = AppTheme.light();

      // Assert
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(theme.colorScheme.primary, AppColors.lightPrimary);
      expect(theme.colorScheme.secondary, AppColors.lightSecondary);
      expect(theme.useMaterial3, isTrue);
    });
  });
}
