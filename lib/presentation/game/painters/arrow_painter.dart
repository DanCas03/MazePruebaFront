import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../direction_projection.dart';

/// Pinta una flecha multi-celda como una POLILÍNEA gruesa (recorre los centros
/// de `cells`) con glow, brillo interior y punta triangular orientada por
/// `headDirection`. Coordenadas locales al bounding box (origen minCol/minRow).
///
/// Agnóstico de la forma: sirve igual para flechas rectas y dobladas —
/// solo depende de `cells` y de `headDirection` (no del último segmento).
class ArrowPainter extends CustomPainter {
  final List<Position> cells;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;
  final Direction headDirection;

  const ArrowPainter({
    required this.cells,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
    required this.headDirection,
  });

  Offset _center(Position p) => Offset(
        (p.col - minCol + 0.5) * cell,
        (p.row - minRow + 0.5) * cell,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final stroke = cell * 0.40;

    final body = Path();
    final first = _center(cells.first);
    body.moveTo(first.dx, first.dy);
    for (final p in cells.skip(1)) {
      final c = _center(p);
      body.lineTo(c.dx, c.dy);
    }

    // Glow (debajo).
    canvas.drawPath(
      body,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.45),
    );

    // Cuerpo.
    canvas.drawPath(
      body,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Brillo interior.
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawHead(canvas, stroke);
  }

  void _drawHead(Canvas canvas, double stroke) {
    final tip = _center(cells.last);
    final angle = directionAngle(headDirection);
    final headLen = stroke * 1.2;
    final headHalf = stroke * 0.95;
    final apex = Offset(
      tip.dx + math.cos(angle) * (cell * 0.5),
      tip.dy + math.sin(angle) * (cell * 0.5),
    );
    final base = Offset(
      apex.dx - math.cos(angle) * headLen,
      apex.dy - math.sin(angle) * headLen,
    );
    final perp = angle + math.pi / 2;
    final left = Offset(
      base.dx + math.cos(perp) * headHalf,
      base.dy + math.sin(perp) * headHalf,
    );
    final right = Offset(
      base.dx - math.cos(perp) * headHalf,
      base.dy - math.sin(perp) * headHalf,
    );
    final head = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant ArrowPainter old) =>
      // `cells` se compara por contenido (listEquals); `Position` es Equatable,
      // así que dos polilíneas con las mismas celdas no fuerzan un repintado.
      !listEquals(old.cells, cells) ||
      old.color != color ||
      old.cell != cell ||
      old.minCol != minCol ||
      old.minRow != minRow ||
      old.headDirection != headDirection;
}
