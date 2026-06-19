import 'package:flutter/material.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Task 1.2 — smoke: AppTheme usa la paleta joya nueva (indigo profundo).
  test('AppTheme.dark usa el fondo oscuro de la paleta', () {
    // Arrange + Act
    final theme = AppTheme.dark();

    // Assert
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.useMaterial3, isTrue);
  });

  test('AppTheme.light usa el fondo claro de la paleta', () {
    // Arrange + Act
    final theme = AppTheme.light();

    // Assert
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(theme.useMaterial3, isTrue);
  });

  // Aserciones conservadas: colorScheme sigue exponiendo primary y secondary
  // (los nombres de campo no cambian, solo los hex de la paleta).
  group('AppTheme.dark — colorScheme', () {
    test('expone primary y secondary de la paleta joya oscura', () {
      // Arrange + Act
      final theme = AppTheme.dark();

      // Assert
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
    });
  });

  group('AppTheme.light — colorScheme', () {
    test('expone primary y secondary de la paleta joya clara', () {
      // Arrange + Act
      final theme = AppTheme.light();

      // Assert
      expect(theme.colorScheme.primary, AppColors.lightPrimary);
      expect(theme.colorScheme.secondary, AppColors.lightSecondary);
    });
  });
}
