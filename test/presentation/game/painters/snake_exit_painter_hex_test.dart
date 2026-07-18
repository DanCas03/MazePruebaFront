import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/direction_projection.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/snake_exit_painter.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  testWidgets('salida hex diagonal usa geometría sin lanzar (downRight)', (t) async {
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2)]; // q=0,r=0; downRight sale al borde
    final painter = SnakeExitPainter(
      cells: cells,
      headDirection: Direction.downRight,
      minCol: 2,
      minRow: 2,
      cols: 5,
      rows: 5,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      progress: 0.5,
      geometry: g,
      origin: g.centerOf(cells.first),
    );
    // Sin geometría esto lanzaría UnimplementedError (cellsToEdge diagonal).
    await t.pumpWidget(Center(
      child: SizedBox(width: 400, height: 400, child: CustomPaint(painter: painter)),
    ));
    final ro = t.renderObject<RenderBox>(find.byType(CustomPaint).first);
    expect(ro, paints..path()); // pinta cuerpo + cabeza sin excepción
  });

  test('con geometry, la polilínea del cuerpo (progress=0) pasa por centerOf(cell) − origin',
      () {
    // Arrange — flecha de 2 celdas (cola→cabeza) downRight sobre HexGeometry;
    // a progress=0 los puntos del cuerpo coinciden exactamente con los centros
    // de celda (sin desplazamiento de arco todavía).
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2), Position(row: 2, col: 3)]; // downRight
    final origin = g.centerOf(cells.first); // origen arbitrario de la caja
    final painter = SnakeExitPainter(
      cells: cells,
      headDirection: Direction.downRight,
      minCol: 2,
      minRow: 2,
      cols: 5,
      rows: 5,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      progress: 0.0,
      geometry: g,
      origin: origin,
    );

    // Act.
    final rec = _RecordingCanvas();
    painter.paint(rec, const Size(400, 400));

    // Assert: el primer path grabado es el cuerpo (glow, pintado antes que
    // el trazo sólido y la cabeza).
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
    // así se prueba que la polilínea siguió la geometría hex, no la fórmula lineal
    // de _laneCells/_center que usaría cellsToEdge.
    expect(end.dx, isNot(closeTo(g.cellSize, tol)),
        reason: 'diagonal hex: dx != cellSize entero, prueba no-lineal');
  });

  test('con geometry, a progress=1 la cola cruza exactamente laneCells·cellSize '
      'del carril real de exitLane (no un valor hardcodeado)', () {
    // Arrange — misma flecha de 2 celdas downRight; a progress=1 el desplazamiento
    // de arco (shift = bodyArc + laneArc) coloca el punto de cola (pts[0]) justo
    // sobre el vértice de trayectoria `laneCells` pasos más allá de la cabeza,
    // donde laneCells = geometry.exitLane(head, dir).length (el carril hex real,
    // no la fórmula lineal). Esto es lo que Task 7 ("carril hex real") debe fijar.
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2), Position(row: 2, col: 3)]; // downRight
    final origin = g.centerOf(cells.first);

    final laneCells = g.exitLane(Position(row: 2, col: 3), Direction.downRight).length;
    final expectedTail = (g.centerOf(Position(row: 2, col: 3)) - origin) +
        directionUnit(Direction.downRight) * (laneCells * g.cellSize);

    final painter = SnakeExitPainter(
      cells: cells,
      headDirection: Direction.downRight,
      minCol: 2,
      minRow: 2,
      cols: 5,
      rows: 5,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      progress: 1.0,
      geometry: g,
      origin: origin,
    );

    // Act.
    final rec = _RecordingCanvas();
    painter.paint(rec, const Size(400, 400));
    final body = rec.paths.first;
    final tail = _start(body);

    // Assert.
    expect(laneCells, greaterThan(0)); // sanity: el carril no debe ser degenerado
    const tol = 1e-3;
    expect(tail.dx, closeTo(expectedTail.dx, tol));
    expect(tail.dy, closeTo(expectedTail.dy, tol));
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
