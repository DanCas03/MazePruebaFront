import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../../core/theme/app_colors.dart';

/// Pinta una flecha multi-celda de forma procedural sobre el [Canvas]
/// (sin SVG ni assets), con profundidad 3D segun el diseno aprobado
/// (decisions/2026-06-17-ui-design.md): cuerpo de color por direccion,
/// sombra proyectada abajo-derecha, bisel/relieve arriba-izquierda, punta
/// triangular clara y un glow purpura cuando la pieza esta resaltada.
class ArrowPainter extends CustomPainter {
  final Arrow arrow;
  final double cellSize;
  final bool isHighlighted;

  const ArrowPainter({
    required this.arrow,
    required this.cellSize,
    this.isHighlighted = false,
  });

  /// Resuelve el color del cuerpo a partir de la direccion. La paleta es la
  /// unica fuente de verdad de color (AppColors); el painter no hardcodea hex.
  static Color bodyColorFor(Direction direction) => switch (direction) {
        Direction.up => AppColors.arrowUp,
        Direction.down => AppColors.arrowDown,
        Direction.left => AppColors.arrowLeft,
        Direction.right => AppColors.arrowRight,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final bodyColor =
        isHighlighted ? AppColors.arrowHighlight : bodyColorFor(arrow.direction);
    final glowColor = AppColors.secondary.withValues(alpha: isHighlighted ? 0.6 : 0.0);
    final bodyPath = _bodyPath();

    // --- Glow layer (detras del cuerpo, solo si esta resaltada) ---
    if (isHighlighted) {
      final glowPaint = Paint()
        ..color = glowColor
        ..strokeWidth = cellSize * 0.55
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawPath(bodyPath, glowPaint);
    }

    // --- Sombra proyectada (offset abajo-derecha, difuminada): sensacion de
    // pieza que flota sobre el tablero. No tapa celdas: blur moderado. ---
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = cellSize * 0.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.save();
    canvas.translate(cellSize * 0.06, cellSize * 0.06);
    canvas.drawPath(bodyPath, shadowPaint);
    canvas.restore();

    // --- Cuerpo de la flecha ---
    final bodyPaint = Paint()
      ..color = bodyColor
      ..strokeWidth = cellSize * 0.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(bodyPath, bodyPaint);

    // --- Bisel/relieve: highlight fino arriba-izquierda sobre el cuerpo ---
    final bevelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = cellSize * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.save();
    canvas.translate(-cellSize * 0.05, -cellSize * 0.05);
    canvas.drawPath(bodyPath, bevelPaint);
    canvas.restore();

    // --- Punta triangular clara ---
    _drawHead(canvas, bodyColor);
  }

  Path _bodyPath() {
    final cells = arrow.cells;
    final path = Path();
    final start = _cellCenter(cells.first);
    path.moveTo(start.dx, start.dy);
    for (final cell in cells.skip(1)) {
      final center = _cellCenter(cell);
      path.lineTo(center.dx, center.dy);
    }
    return path;
  }

  Offset _cellCenter(Position pos) => Offset(
        (pos.col + 0.5) * cellSize,
        (pos.row + 0.5) * cellSize,
      );

  void _drawHead(Canvas canvas, Color color) {
    final headCenter = _cellCenter(arrow.head);
    final angle = switch (arrow.direction) {
      Direction.right => 0.0,
      Direction.left => math.pi,
      Direction.down => math.pi / 2,
      Direction.up => -math.pi / 2,
    };
    final size = cellSize * 0.3;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(headCenter.dx + math.cos(angle) * size,
          headCenter.dy + math.sin(angle) * size)
      ..lineTo(headCenter.dx + math.cos(angle + 2.6) * size,
          headCenter.dy + math.sin(angle + 2.6) * size)
      ..lineTo(headCenter.dx + math.cos(angle - 2.6) * size,
          headCenter.dy + math.sin(angle - 2.6) * size)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ArrowPainter old) =>
      old.arrow != arrow || old.isHighlighted != isHighlighted;
}
