import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

// ---------------------------------------------------------------------------
// Tests for GraphBoardGenerator.generateThemed (#68): region-confined bodies,
// paintRole tagging, global DAG preservation, determinism, and proof that the
// campaign path generate(...) is untouched (paintRole stays null).
// ---------------------------------------------------------------------------
const _cols = 12;
const _rows = 12;

/// Two DISJOINT halves of a 12x12 board: "left" (col < 6) and "right"
/// (col >= 6). Disjointness makes the confinement assertion unambiguous.
List<ThemedRegionSpec> _twoHalves() {
  final left = <Position>{
    for (var r = 0; r < _rows; r++)
      for (var c = 0; c < 6; c++) Position(row: r, col: c),
  };
  final right = <Position>{
    for (var r = 0; r < _rows; r++)
      for (var c = 6; c < _cols; c++) Position(row: r, col: c),
  };
  return [
    ThemedRegionSpec(role: 'left', cells: left, arrowCount: 6, maxPathLen: 4),
    ThemedRegionSpec(role: 'right', cells: right, arrowCount: 6, maxPathLen: 4),
  ];
}

void main() {
  group('GraphBoardGenerator.generateThemed', () {
    test('confines every arrow body to the region matching its paintRole '
        '(property test, seeds 0..20)', () {
      // Arrange
      final generator = GraphBoardGenerator();
      final regions = _twoHalves();
      final cellsByRole = {for (final r in regions) r.role: r.cells};

      for (var seed = 0; seed <= 20; seed++) {
        // Act
        final board = generator.generateThemed(
            cols: _cols, rows: _rows, regions: regions, seed: seed);

        // Assert
        for (final arrow in board.arrows) {
          final regionCells = cellsByRole[arrow.paintRole];
          expect(regionCells, isNotNull,
              reason: 'seed=$seed: unknown paintRole ${arrow.paintRole}');
          for (final cell in arrow.cells) {
            expect(regionCells, contains(cell),
                reason: 'seed=$seed: arrow ${arrow.id} (role '
                    '${arrow.paintRole}) has body cell outside its region');
          }
        }
      }
    });

    test('tags every placed arrow with a non-null region paintRole', () {
      // Arrange
      final generator = GraphBoardGenerator();
      final regions = _twoHalves();
      final roles = {for (final r in regions) r.role};

      // Act
      final board = generator.generateThemed(
          cols: _cols, rows: _rows, regions: regions, seed: 42);

      // Assert
      expect(board.arrows, isNotEmpty);
      for (final arrow in board.arrows) {
        expect(arrow.paintRole, isNotNull);
        expect(roles, contains(arrow.paintRole));
      }
    });

    test('places arrows without any cell overlap across regions', () {
      // Arrange
      final generator = GraphBoardGenerator();
      final regions = _twoHalves();

      // Act
      final board = generator.generateThemed(
          cols: _cols, rows: _rows, regions: regions, seed: 7);

      // Assert
      final seen = <Position>{};
      for (final arrow in board.arrows) {
        for (final cell in arrow.cells) {
          expect(seen.add(cell), isTrue,
              reason: 'cell $cell is shared by two arrows');
        }
      }
    });

    test('board empties in reverse placement order (global DAG invariant)',
        () {
      // Arrange
      final generator = GraphBoardGenerator();
      final regions = _twoHalves();

      // Act
      final board = generator.generateThemed(
          cols: _cols, rows: _rows, regions: regions, seed: 11);

      // Assert
      var live = board;
      for (final a in board.arrows.reversed) {
        expect(live.canExit(a.id), isTrue,
            reason: 'arrow ${a.id} cannot exit in reverse placement order');
        live = live.removeArrow(a.id);
      }
      expect(live.isCleared, isTrue);
    });

    test('is deterministic: same regions + same seed produce equal boards',
        () {
      // Arrange
      final generator = GraphBoardGenerator();

      // Act
      final boardA = generator.generateThemed(
          cols: _cols, rows: _rows, regions: _twoHalves(), seed: 99);
      final boardB = generator.generateThemed(
          cols: _cols, rows: _rows, regions: _twoHalves(), seed: 99);

      // Assert (ArrowBoard/Arrow are Equatable: ids, cells, paintRole)
      expect(boardA, equals(boardB));
    });

    test('generate() campaign path is untouched: paintRole stays null', () {
      // Arrange
      final generator = GraphBoardGenerator();

      // Act
      final ArrowBoard board = generator.generate(
          cols: 8, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 7);

      // Assert
      expect(board.arrows, isNotEmpty);
      for (final arrow in board.arrows) {
        expect(arrow.paintRole, isNull);
      }
    });
  });
}
