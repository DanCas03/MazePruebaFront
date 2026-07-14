import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

// ---------------------------------------------------------------------------
// Performance budget for #64 (ADR 0003: campaign finale + XL presets at 50x50).
// Rampa T5 density: 50x50 · fillRatio 0.65 · maxPathLen 12 → target cells
// ≈ 1625; with an average bent body of ~7 cells that is ~232 arrows.
// ---------------------------------------------------------------------------
const _cols = 50;
const _rows = 50;
const _arrowCount = 232;
const _maxPathLen = 12;
const _seed = 64;

/// Strict reverse-placement-order removal: ids are arrow-0..arrow-N in
/// placement order, so removing from the highest index down must always find
/// a free exit lane (DAG invariant) and end with an empty board.
bool _emptiesInReverseOrder(ArrowBoard board) {
  final sorted = List<Arrow>.from(board.arrows)
    ..sort((a, b) {
      final ai = int.tryParse(a.id.value.replaceFirst('arrow-', '')) ?? 0;
      final bi = int.tryParse(b.id.value.replaceFirst('arrow-', '')) ?? 0;
      return ai.compareTo(bi);
    });
  var b = board;
  for (final arrow in sorted.reversed) {
    if (!b.canExit(arrow.id)) return false;
    b = b.removeArrow(arrow.id);
  }
  return b.isCleared;
}

void main() {
  group('GraphBoardGenerator — 50x50 dense performance (#64)', () {
    test('generates a dense 50x50 board in < 2 s', () {
      // Arrange
      final gen = GraphBoardGenerator();
      final stopwatch = Stopwatch();

      // Act
      stopwatch.start();
      final board = gen.generate(
          cols: _cols,
          rows: _rows,
          arrowCount: _arrowCount,
          maxPathLen: _maxPathLen,
          seed: _seed);
      stopwatch.stop();

      // Assert — performance budget from the brief (desktop test runner).
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: '50x50 dense generation took ${stopwatch.elapsedMilliseconds}ms '
              '(budget: < 2000ms)');
      expect(board.cols, _cols);
      expect(board.rows, _rows);
      expect(board.arrows, isNotEmpty);
    });

    test('the dense 50x50 board is valid: no overlaps and orthogonal bodies', () {
      // Arrange
      final gen = GraphBoardGenerator();

      // Act
      final board = gen.generate(
          cols: _cols,
          rows: _rows,
          arrowCount: _arrowCount,
          maxPathLen: _maxPathLen,
          seed: _seed);

      // Assert — no cell shared between arrows.
      final allCells = <Position>[
        for (final a in board.arrows) ...a.cells,
      ];
      expect(allCells.toSet().length, allCells.length,
          reason: 'Dense board has overlapping arrow cells');

      // Assert — every body: in range, length in [2, maxPathLen], distinct,
      // orthogonally adjacent consecutive cells.
      for (final arrow in board.arrows) {
        expect(arrow.cells.length, inInclusiveRange(2, _maxPathLen),
            reason: 'Arrow ${arrow.id.value} body length out of range');
        expect(arrow.cells.toSet().length, arrow.cells.length,
            reason: 'Arrow ${arrow.id.value} repeats cells');
        for (final cell in arrow.cells) {
          expect(cell.col, inInclusiveRange(0, _cols - 1));
          expect(cell.row, inInclusiveRange(0, _rows - 1));
        }
        for (var i = 0; i < arrow.cells.length - 1; i++) {
          final a = arrow.cells[i];
          final b = arrow.cells[i + 1];
          expect((a.row - b.row).abs() + (a.col - b.col).abs(), 1,
              reason: 'Arrow ${arrow.id.value}: cells $i and ${i + 1} '
                  'are not orthogonally adjacent');
        }
      }
    });

    test('the dense 50x50 board empties in reverse placement order (solvable)', () {
      // Arrange
      final gen = GraphBoardGenerator();
      final board = gen.generate(
          cols: _cols,
          rows: _rows,
          arrowCount: _arrowCount,
          maxPathLen: _maxPathLen,
          seed: _seed);

      // Act
      final solvable = _emptiesInReverseOrder(board);

      // Assert
      expect(solvable, isTrue,
          reason: 'Dense 50x50 board is not solvable in reverse placement order');
    });

    test('seed→output determinism holds at 50x50 for the new version', () {
      // Arrange
      final gen = GraphBoardGenerator();

      // Act
      final boardA = gen.generate(
          cols: _cols,
          rows: _rows,
          arrowCount: _arrowCount,
          maxPathLen: _maxPathLen,
          seed: _seed);
      final boardB = gen.generate(
          cols: _cols,
          rows: _rows,
          arrowCount: _arrowCount,
          maxPathLen: _maxPathLen,
          seed: _seed);

      // Assert — Equatable equality covers cells + headDirection per arrow.
      expect(boardA, equals(boardB));
    });
  });
}
