import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Define los ThemeData claro y oscuro de Arrow Maze. El oscuro es el "hero"
/// (índigo profundo + tonos joya); el claro es su contraparte. `MaterialApp`
/// con `ThemeMode.system` selecciona según el sistema.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onBackground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onBackground,
      surface: AppColors.surface,
      onSurface: AppColors.onBackground,
      error: AppColors.error,
      onError: AppColors.background,
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightSurface,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.lightSurface,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnBackground,
      error: AppColors.error,
      onError: AppColors.lightSurface,
    );
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}
