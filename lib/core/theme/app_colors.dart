import 'package:flutter/material.dart';

/// Paleta de Arrow Maze — índigo profundo + tonos joya maduros. Es la fuente
/// única de verdad de color; widgets y painters no hardcodean hex. El color
/// por flecha vive en presentación (ver arrow_color.dart), no en el dominio.
class AppColors {
  AppColors._();

  // --- Tema oscuro (protagonista) ---
  static const Color background = Color(0xFF0E1020);
  static const Color backgroundDeep = Color(0xFF070812);
  static const Color surface = Color(0xFF181B30);
  static const Color pill = Color(0xFF242843);
  static const Color onBackground = Color(0xFFE6E8F5);
  static const Color onSurfaceMuted = Color(0xFF7E84A8);
  static const Color primary = Color(0xFF5B6CC4); // seed / CTA
  static const Color secondary = Color(0xFF8A6FD0); // acento violeta (glow)
  static const Color victory = Color(0xFFE0B45A);

  static const Color glassBorder = Color(0x26FFFFFF); // blanco ~15%
  static const Color glassFill = Color(0x14FFFFFF); // blanco ~8%

  // Estado
  static const Color success = Color(0xFF46B98C);
  static const Color warning = Color(0xFFD7A24A);
  static const Color error = Color(0xFFCF646F);

  // --- Tema claro (contraparte) ---
  static const Color lightBackground = Color(0xFFF4F5FB);
  static const Color lightBackgroundDeep = Color(0xFFE7E9F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPill = Color(0xFFE7E9F5);
  static const Color lightOnBackground = Color(0xFF1B1E33);
  static const Color lightOnSurfaceMuted = Color(0xFF6B7095);
  static const Color lightPrimary = Color(0xFF4B5BB5);
  static const Color lightSecondary = Color(0xFF7C5FC0);

  static const Color lightGlassBorder = Color(0x14000000); // negro ~8%
  static const Color lightGlassFill = Color(0x0A000000); // negro ~4%

  // --- Paleta de flechas (tonos joya). Indexada por flecha desde presentación. ---
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

  /// Resuelve el color de una flecha por índice (wrap-around módulo la paleta).
  static Color arrowColor(int index) =>
      arrowPalette[index % arrowPalette.length];
}
