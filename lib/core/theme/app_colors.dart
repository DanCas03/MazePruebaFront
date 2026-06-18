import 'package:flutter/material.dart';

/// Paleta de Arrow Maze — "Dark neon" con fondo casi-negro neutro y su
/// contraparte clara frosted-on-light. Hex aprobados por el usuario
/// (decisions/2026-06-17-ui-design.md). Estas constantes son la fuente unica
/// de verdad de color; ni widgets ni painters hardcodean hex.
class AppColors {
  AppColors._();

  // --- Tema oscuro (protagonista) ---
  static const Color background = Color(0xFF0A0A0C); // casi negro neutro
  static const Color surface = Color(0xFF141417); // superficie elevada
  static const Color glassBorder = Color(0x26FFFFFF); // blanco ~15%
  static const Color glassFill = Color(0x14FFFFFF); // blanco ~8%
  static const Color primary = Color(0xFF22D3EE); // cyan neon
  static const Color secondary = Color(0xFFA855F7); // purpura accent
  static const Color onBackground = Color(0xFFE5E7EB); // texto on-dark
  static const Color onSurfaceMuted = Color(0xFF94A3B8); // texto muted

  // Flechas por direccion (tema oscuro)
  static const Color arrowUp = Color(0xFFFB7185);
  static const Color arrowDown = Color(0xFF38BDF8);
  static const Color arrowLeft = Color(0xFF34D399);
  static const Color arrowRight = Color(0xFFFBBF24);

  // Cuerpo de flecha resaltada (seleccion): blanco casi puro para que el glow
  // purpura (secondary) y el bisel destaquen sobre la pieza activa.
  static const Color arrowHighlight = Color(0xFFF8FAFC);

  // Estado (tema oscuro)
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFB7185);

  // --- Tema claro (contraparte, "seguir sistema") ---
  static const Color lightBackground = Color(0xFFF4F4F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightGlassBorder = Color(0x14000000); // negro ~8%
  static const Color lightGlassFill = Color(0x0A000000); // negro ~4%
  static const Color lightPrimary = Color(0xFF06B6D4); // cyan profundizado
  static const Color lightSecondary = Color(0xFF9333EA); // purpura profundizado
  static const Color lightOnBackground = Color(0xFF111827);
  static const Color lightOnSurfaceMuted = Color(0xFF475569);
}
