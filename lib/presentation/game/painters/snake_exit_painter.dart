import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../direction_projection.dart';
import '../geometry/board_geometry.dart';

/// Retracción "serpiente": construye la trayectoria (centros del cuerpo
/// cola→cabeza ++ carril recto más allá del borde) y, a progreso [progress],
/// desplaza cada vértice del cuerpo esa distancia de arco hacia delante. La
/// cabeza sale primero y la cola la sigue por el mismo camino.
class SnakeExitPainter extends CustomPainter {
  final List<Position> cells; // cola (first) .. cabeza (last)
  final Direction headDirection;
  final int minCol;
  final int minRow;
  final int cols;
  final int rows;
  final double cell;
  final Color color;
  final double progress; // 0..1
  // front#126: cuando no es null, los centros vienen de la geometría (hex) y
  // el carril de salida se mide en el espacio real (`exitLane`), no con la
  // fórmula lineal `cellsToEdge` (que lanza en diagonales). `cell` pasa a
  // interpretarse como `cellSize` para los grosores de trazo. Ausente =>
  // camino lineal rect intacto (lo cubren los tests rect existentes, incluido
  // el bug masked-rect conocido).
  final BoardGeometry? geometry;
  final Offset origin;

  const SnakeExitPainter({
    required this.cells,
    required this.headDirection,
    required this.minCol,
    required this.minRow,
    required this.cols,
    required this.rows,
    required this.cell,
    required this.color,
    required this.progress,
    this.geometry,
    this.origin = Offset.zero,
  });

  Offset _center(Position p) => geometry != null
      ? geometry!.centerOf(p) - origin
      : Offset((p.col - minCol + 0.5) * cell, (p.row - minRow + 0.5) * cell);

  int _laneCells() => geometry != null
      ? geometry!.exitLane(cells.last, headDirection).length
      : cellsToEdge(cells.last, headDirection, cols: cols, rows: rows);

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;

    final traj = <Offset>[for (final p in cells) _center(p)];
    final unit = directionUnit(headDirection);
    final headC = traj.last;
    final beyond = cells.length + _laneCells() + 1; // margen para salir entero
    for (var i = 1; i <= beyond; i++) {
      traj.add(Offset(headC.dx + unit.dx * i * cell, headC.dy + unit.dy * i * cell));
    }

    final cum = <double>[0];
    for (var i = 1; i < traj.length; i++) {
      cum.add(cum[i - 1] + (traj[i] - traj[i - 1]).distance);
    }

    final bodyArc = cum[cells.length - 1];
    final laneArc = _laneCells() * cell;
    final shift = progress * (bodyArc + laneArc); // a t=1 la cola cruza el borde

    final pts = <Offset>[
      for (var k = 0; k < cells.length; k++) _along(traj, cum, cum[k] + shift),
    ];

    _strokeBody(canvas, pts);
    _drawHead(canvas, pts.last, unit);
  }

  Offset _along(List<Offset> traj, List<double> cum, double d) {
    if (d <= 0) return traj.first;
    if (d >= cum.last) return traj.last;
    var i = 1;
    while (i < cum.length && cum[i] < d) {
      i++;
    }
    final t = (d - cum[i - 1]) / (cum[i] - cum[i - 1]);
    return Offset.lerp(traj[i - 1], traj[i], t)!;
  }

  void _strokeBody(Canvas canvas, List<Offset> pts) {
    final stroke = cell * 0.40;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.45),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawHead(Canvas canvas, Offset tip, Offset unit) {
    final stroke = cell * 0.40;
    final angle = math.atan2(unit.dy, unit.dx);
    final headLen = stroke * 1.2;
    final headHalf = stroke * 0.95;
    final apex = Offset(tip.dx + unit.dx * cell * 0.5, tip.dy + unit.dy * cell * 0.5);
    final base =
        Offset(apex.dx - math.cos(angle) * headLen, apex.dy - math.sin(angle) * headLen);
    final perp = angle + math.pi / 2;
    final left =
        Offset(base.dx + math.cos(perp) * headHalf, base.dy + math.sin(perp) * headHalf);
    final right =
        Offset(base.dx - math.cos(perp) * headHalf, base.dy - math.sin(perp) * headHalf);
    canvas.drawPath(
      Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant SnakeExitPainter old) =>
      old.progress != progress ||
      old.cells != cells ||
      old.color != color ||
      old.cell != cell ||
      old.geometry != geometry ||
      old.origin != origin;
}
