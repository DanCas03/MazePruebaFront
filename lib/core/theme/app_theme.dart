// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Paleta centralizada del juego: tonos joya maduros y desaturados sobre un
/// fondo índigo profundo. Controlada y premium (sin neón "caramelo").
abstract final class AppColors {
  static const Color background = Color(0xFF0E1020);
  static const Color backgroundDeep = Color(0xFF070812);
  static const Color surface = Color(0xFF181B30);
  static const Color pill = Color(0xFF242843);
  static const Color onSurface = Color(0xFFE6E8F5);
  static const Color muted = Color(0xFF7E84A8);
  static const Color seed = Color(0xFF5B6CC4);
  static const Color victory = Color(0xFFE0B45A);

  /// Paleta de las flechas (tonos joya maduros). El `colorIndex` del dominio
  /// indexa aquí (módulo la longitud), manteniendo el dominio libre de Flutter.
  static const List<Color> arrowPalette = <Color>[
    Color(0xFF46B98C), // esmeralda
    Color(0xFF39ACBE), // teal
    Color(0xFFD56C8E), // rosa
    Color(0xFFD7A24A), // ámbar
    Color(0xFFC9764E), // terracota
    Color(0xFF8A6FD0), // violeta
    Color(0xFF5E7AD0), // índigo
    Color(0xFFCF646F), // rojo apagado
  ];

  static Color arrowColor(int colorIndex) =>
      arrowPalette[colorIndex % arrowPalette.length];
}

/// Configuración de tema (Material 3, modo oscuro neón).
abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.background,
      onSurface: AppColors.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
    );
  }
}
