import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/board_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/rect_geometry.dart';

void main() {
  const c = BoxConstraints(maxWidth: 100, maxHeight: 200); // 4x4 => cell=25

  test('forSpace(RectSpace) devuelve RectGeometry', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g, isA<RectGeometry>());
  });

  test('size y cellSize reproducen min(maxW/cols, maxH/rows)', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g.cellSize, 25.0);
    expect(g.size, const Size(100, 100));
  });

  test('centerOf reproduce (col-minCol+0.5)*cell', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g.centerOf(Position(row: 0, col: 0)), const Offset(12.5, 12.5));
    expect(g.centerOf(Position(row: 2, col: 3)), const Offset(87.5, 62.5));
  });

  test('cellAt reproduce floor(dx/cell) con clamp a bounds', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g.cellAt(const Offset(12.5, 12.5)), Position(row: 0, col: 0));
    expect(g.cellAt(const Offset(87.5, 62.5)), Position(row: 2, col: 3));
    // fuera por arriba/izquierda => clamp a la celda de borde
    expect(g.cellAt(const Offset(-5, -5)), Position(row: 0, col: 0));
  });
}
