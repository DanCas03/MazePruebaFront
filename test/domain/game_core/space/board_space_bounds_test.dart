import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/board_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/bounding_box.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espacio NO rectangular de test: celdas fijas, SIN override de `bounds`, así
/// que ejercita el default derivado de `allCells`. `step` no se usa aquí.
class _SparseSpace extends BoardSpace {
  final List<Position> cells;
  const _SparseSpace(this.cells);
  @override
  Iterable<Direction> get directions => Direction.values;
  @override
  bool contains(Position pos) => cells.contains(pos);
  @override
  Position? step(Position pos, Direction dir) => null;
  @override
  int get cellCount => cells.length;
  @override
  Iterable<Position> get allCells => cells;
  @override
  BoardSpace masked(Set<Position> activeCells) =>
      throw UnimplementedError('_SparseSpace no participa en montaje enmascarado');
  @override
  List<Object?> get props => [cells];
}

void main() {
  group('BoardSpace.bounds', () {
    test('RectSpace expone su caja O(1) desde el origen', () {
      // Arrange — RectSpace(cols, rows) = (8, 11).
      const space = RectSpace(8, 11);
      // Act & Assert
      expect(
        space.bounds,
        const BoundingBox(minRow: 0, minCol: 0, rows: 11, cols: 8),
      );
    });

    test('el default deriva la caja ajustada de allCells (fuera del origen)', () {
      // Arrange — celdas en filas 2..4, cols 3..5.
      final space = _SparseSpace([
        Position(row: 2, col: 3),
        Position(row: 4, col: 5),
        Position(row: 3, col: 4),
      ]);
      // Act & Assert — caja mínima que las contiene.
      expect(
        space.bounds,
        const BoundingBox(minRow: 2, minCol: 3, rows: 3, cols: 3),
      );
    });

    test('el default de un espacio vacío es una caja vacía', () {
      // Arrange & Act & Assert
      const space = _SparseSpace([]);
      expect(space.bounds.isEmpty, isTrue);
    });
  });

  group('ArrowBoard.cols/rows', () {
    test('delegan en space.bounds sin castear a RectSpace', () {
      // Arrange — un espacio NO rectangular: el cast previo
      // `(space as RectSpace)` habría lanzado aquí.
      final space = _SparseSpace([
        Position(row: 2, col: 3),
        Position(row: 2, col: 4),
      ]);
      final board = ArrowBoard(
        arrows: [
          Arrow(
            id: const ArrowId('a1'),
            headDirection: Direction.right,
            cells: [Position(row: 2, col: 3), Position(row: 2, col: 4)],
          ),
        ],
        space: space,
      );
      // Act & Assert — cols/rows salen de la caja (1 fila × 2 cols), sin crash.
      expect(board.rows, 1);
      expect(board.cols, 2);
    });
  });
}
