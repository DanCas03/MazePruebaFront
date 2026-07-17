import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

import '../../../tool/level_production/validation.dart';

// ---------------------------------------------------------------------------
// Tests for GraphBoardGenerator.generateThemedFull (#114): full-coverage
// themed silhouette fill with STRAIGHT arrows, every arrow >= 2 cells,
// bodies confined to their region, solvable by construction (peeling DAG).
// ---------------------------------------------------------------------------

/// Solid rectangle of cells starting at (r0, c0), spanning rows x cols.
Set<Position> _rect(int r0, int c0, int rows, int cols) => {
      for (var r = r0; r < r0 + rows; r++)
        for (var c = c0; c < c0 + cols; c++) Position(row: r, col: c),
    };

/// Single-region solid 4x4 mask: the full-coverage baseline.
List<ThemedRegionSpec> _solidSquare() => [
      ThemedRegionSpec(
        role: 'body',
        cells: _rect(0, 0, 4, 4),
        arrowCount: 0, // ignored by generateThemedFull
        maxPathLen: 6, // ignored by generateThemedFull
      ),
    ];

/// Two-region cross in a 5x5 frame: vertical "stem" (col 2, rows 0..4) and
/// horizontal "bar" (row 2, cols 0..4 minus the centre, which belongs to the
/// stem). Cells belong to exactly one region; the bar is split in two by the
/// stem, forcing region-confined straight bodies of length 2.
List<ThemedRegionSpec> _cross() {
  final stem = <Position>{
    for (var r = 0; r < 5; r++) Position(row: r, col: 2),
  };
  final bar = <Position>{
    for (var c = 0; c < 5; c++)
      if (c != 2) Position(row: 2, col: c),
  };
  return [
    ThemedRegionSpec(role: 'stem', cells: stem, arrowCount: 0, maxPathLen: 6),
    ThemedRegionSpec(role: 'bar', cells: bar, arrowCount: 0, maxPathLen: 6),
  ];
}

void main() {
  group('GraphBoardGenerator.generateThemedFull', () {
    test('every arrow has at least 2 cells', () {
      // Arrange
      final generator = GraphBoardGenerator();

      for (final (name, cols, rows, regions) in [
        ('solid 4x4', 4, 4, _solidSquare()),
        ('cross 5x5', 5, 5, _cross()),
      ]) {
        // Act
        final board = generator.generateThemedFull(
            cols: cols, rows: rows, regions: regions);

        // Assert
        expect(board.arrows, isNotEmpty, reason: '$name: no arrows placed');
        for (final arrow in board.arrows) {
          expect(arrow.cells.length, greaterThanOrEqualTo(2),
              reason: '$name: arrow ${arrow.id} has < 2 cells');
        }
      }
    });

    test('every arrow body is confined to the region matching its paintRole',
        () {
      // Arrange
      final generator = GraphBoardGenerator();
      final regions = _cross();
      final cellsByRole = {for (final r in regions) r.role: r.cells};

      // Act
      final board =
          generator.generateThemedFull(cols: 5, rows: 5, regions: regions);

      // Assert
      for (final arrow in board.arrows) {
        final regionCells = cellsByRole[arrow.paintRole];
        expect(regionCells, isNotNull,
            reason: 'unknown paintRole ${arrow.paintRole}');
        for (final cell in arrow.cells) {
          expect(regionCells, contains(cell),
              reason: 'arrow ${arrow.id} (role ${arrow.paintRole}) has a '
                  'body cell outside its region');
        }
      }
    });

    test('board is solvable: passes candidate validation (no overlap + '
        'empties in reverse placement order)', () {
      // Arrange
      final generator = GraphBoardGenerator();

      for (final (name, cols, rows, regions) in [
        ('solid 4x4', 4, 4, _solidSquare()),
        ('cross 5x5', 5, 5, _cross()),
      ]) {
        // Act
        final board = generator.generateThemedFull(
            cols: cols, rows: rows, regions: regions);

        // Assert: validateCandidate throws on overlap or unsolvable DAG.
        expect(() => validateCandidate(board), returnsNormally,
            reason: '$name: board failed candidate validation');
      }
    });

    test('covers 100% of a solid rectangular single-region mask', () {
      // Arrange
      final generator = GraphBoardGenerator();
      final regions = _solidSquare();
      final activeCells = regions.single.cells;

      // Act
      final board =
          generator.generateThemedFull(cols: 4, rows: 4, regions: regions);

      // Assert: the union of arrow cells is exactly the mask.
      final covered = <Position>{
        for (final arrow in board.arrows) ...arrow.cells,
      };
      expect(covered, equals(activeCells),
          reason: 'coverage is ${covered.length}/${activeCells.length} cells');
    });

    test('arrow ids read arrow-0..arrow-N in placement (list) order', () {
      // Arrange
      final generator = GraphBoardGenerator();

      // Act
      final board = generator.generateThemedFull(
          cols: 4, rows: 4, regions: _solidSquare());

      // Assert
      for (var i = 0; i < board.arrows.length; i++) {
        expect(board.arrows[i].id.value, 'arrow-$i');
      }
    });
  });
}
