import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  testWidgets('con geometry, la flecha recorre centros hex (no lineales)', (t) async {
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2), Position(row: 2, col: 3)]; // downRight
    final origin = g.centerOf(cells.first); // origen arbitrario de la caja
    final painter = ArrowPainter(
      cells: cells,
      minCol: 2,
      minRow: 2,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      headDirection: Direction.downRight,
      geometry: g,
      origin: origin,
    );
    await t.pumpWidget(Center(
      child: SizedBox(width: 400, height: 400, child: CustomPaint(painter: painter)),
    ));
    final ro = t.renderObject<RenderBox>(find.byType(CustomPaint).first);
    // El cuerpo se pinta como path (glow + cuerpo + brillo) + cabeza => >=4 drawPath.
    expect(ro, paintsExactlyCountTimes(#drawPath, 4));
  });

  test('con geometry, la polilínea del cuerpo pasa por centerOf(cell) − origin', () {
    // Arrange.
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2), Position(row: 2, col: 3)]; // downRight
    final origin = g.centerOf(cells.first);
    final painter = ArrowPainter(
      cells: cells,
      minCol: 2,
      minRow: 2,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      headDirection: Direction.downRight,
      geometry: g,
      origin: origin,
    );

    // Act.
    final rec = _RecordingCanvas();
    painter.paint(rec, const Size(400, 400));

    // Assert: el primer path grabado (glow) es la polilínea del cuerpo.
    final body = rec.paths.first;
    final start = _start(body);
    final end = _end(body);

    final expectedStart = g.centerOf(cells[0]) - origin; // == Offset.zero
    final expectedEnd = g.centerOf(cells[1]) - origin;

    // Path (Skia) almacena las coordenadas en precisión simple (float32);
    // tolerancia laxa para absorber ese redondeo, sigue siendo << 1 celda.
    const tol = 1e-3;
    expect(start.dx, closeTo(expectedStart.dx, tol));
    expect(start.dy, closeTo(expectedStart.dy, tol));
    expect(end.dx, closeTo(expectedEnd.dx, tol));
    expect(end.dy, closeTo(expectedEnd.dy, tol));

    // El delta no debe coincidir con el paso lineal rect (dx == cellSize, dy == 0):
    // así se prueba que la polilínea siguió la geometría hex, no la fórmula lineal.
    expect(end.dx, isNot(closeTo(g.cellSize, tol)),
        reason: 'diagonal hex: dx != cellSize entero, prueba no-lineal');
  });
}

class _RecordingCanvas implements Canvas {
  final List<Path> paths = [];
  @override
  void drawPath(Path path, Paint paint) => paths.add(path);
  @override
  void noSuchMethod(Invocation invocation) {}
}

Offset _start(Path p) => p.computeMetrics().first.getTangentForOffset(0)!.position;
Offset _end(Path p) {
  final m = p.computeMetrics().first;
  return m.getTangentForOffset(m.length)!.position;
}
