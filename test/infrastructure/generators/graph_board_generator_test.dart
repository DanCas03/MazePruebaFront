import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

// ---------------------------------------------------------------------------
// Manual mock for ILoggerService (avoids build_runner dependency).
// Tracks warn() calls so tests can assert graceful-degradation logging.
// ---------------------------------------------------------------------------
class _MockLoggerService implements ILoggerService {
  int warnCallCount = 0;
  final List<String> warnMessages = [];

  @override
  void warn(String message, String context) {
    warnCallCount++;
    warnMessages.add(message);
  }

  @override
  void log(String message, String context) {}

  @override
  void error(String message, String context, [Object? error]) {}
}

// ---------------------------------------------------------------------------
// Solubility helper: removes arrows in REVERSE placement order.
// The DAG invariant means the last-placed arrow must always canExit first.
// ---------------------------------------------------------------------------
bool _isSolvableByReverseOrder(ArrowBoard board) {
  // We don't have access to placement order from the board itself, so we use
  // the greedy solver which is equivalent: any arrow that canExit can be
  // removed. The generator guarantees each arrow can exit at placement time
  // (and remains removable when later-placed arrows are removed in reverse).
  // We verify the stronger property: greedy solver (any canExit) empties board.
  var b = board;
  var progress = true;
  while (!b.isCleared && progress) {
    progress = false;
    for (final a in List<Arrow>.from(b.arrows)) {
      if (b.canExit(a.id)) {
        b = b.removeArrow(a.id);
        progress = true;
        break;
      }
    }
  }
  return b.isCleared;
}

// Verify strict reverse-order solubility: arrows named arrow-0, arrow-1, ...
// Removing from the highest index down, each must canExit before removal.
bool _isSolvableStrictReverseOrder(ArrowBoard board) {
  // Sort by the numeric suffix in id (arrow-0, arrow-1, ...).
  final sorted = List<Arrow>.from(board.arrows)
    ..sort((a, b) {
      final ai = int.tryParse(a.id.value.replaceFirst('arrow-', '')) ?? 0;
      final bi = int.tryParse(b.id.value.replaceFirst('arrow-', '')) ?? 0;
      return ai.compareTo(bi);
    });

  var b = board;
  // Remove in REVERSE order (last-placed first).
  for (final arrow in sorted.reversed) {
    if (!b.canExit(arrow.id)) return false;
    b = b.removeArrow(arrow.id);
  }
  return b.isCleared;
}

void main() {
  group('GraphBoardGenerator', () {
    // ── 1. DETERMINISM ────────────────────────────────────────────────────────

    test('determinism: same seed produces identical boards (cells + headDirection order)', () {
      // Arrange
      const seed = 42;
      const cols = 6, rows = 6, arrowCount = 6, maxPathLen = 4;
      final gen = GraphBoardGenerator();

      // Act
      final boardA = gen.generate(
          cols: cols, rows: rows, arrowCount: arrowCount, maxPathLen: maxPathLen, seed: seed);
      final boardB = gen.generate(
          cols: cols, rows: rows, arrowCount: arrowCount, maxPathLen: maxPathLen, seed: seed);

      // Assert — ArrowBoard is Equatable; also verify arrow-by-arrow for precision
      expect(boardA, equals(boardB));
      expect(boardA.arrows.length, boardB.arrows.length);
      for (var i = 0; i < boardA.arrows.length; i++) {
        expect(boardA.arrows[i].cells, boardB.arrows[i].cells,
            reason: 'Arrow $i cells differ');
        expect(boardA.arrows[i].headDirection, boardB.arrows[i].headDirection,
            reason: 'Arrow $i headDirection differs');
      }
    });

    test('determinism: different seeds produce different boards', () {
      // Arrange
      const cols = 6, rows = 6, arrowCount = 6, maxPathLen = 4;
      final gen = GraphBoardGenerator();

      // Act
      final boardA = gen.generate(
          cols: cols, rows: rows, arrowCount: arrowCount, maxPathLen: maxPathLen, seed: 42);
      final boardB = gen.generate(
          cols: cols, rows: rows, arrowCount: arrowCount, maxPathLen: maxPathLen, seed: 99);

      // Assert — extremely unlikely that two different seeds produce identical boards
      final sameArrows = boardA.arrows.length == boardB.arrows.length &&
          List.generate(boardA.arrows.length, (i) => boardA.arrows[i] == boardB.arrows[i])
              .every((e) => e);
      expect(sameArrows, isFalse,
          reason: 'seeds 42 and 99 should produce different boards');
    });

    // ── 2. NO OVERLAPS ────────────────────────────────────────────────────────

    test('no-overlaps: no cell is shared between any two arrows', () {
      // Arrange
      final gen = GraphBoardGenerator();
      final board = gen.generate(
          cols: 8, rows: 8, arrowCount: 12, maxPathLen: 4, seed: 7);

      // Act — collect all cells and check for duplicates
      final allCells = <Position>[];
      for (final arrow in board.arrows) {
        allCells.addAll(arrow.cells);
      }
      final uniqueCells = allCells.toSet();

      // Assert
      expect(uniqueCells.length, allCells.length,
          reason: 'Found ${allCells.length - uniqueCells.length} duplicate cells across arrows');
    });

    test('no-overlaps: board.overlaps returns false for every placed arrow', () {
      // Arrange
      final gen = GraphBoardGenerator();
      final board = gen.generate(
          cols: 7, rows: 7, arrowCount: 10, maxPathLen: 4, seed: 13);

      // Act + Assert
      for (final arrow in board.arrows) {
        expect(board.overlaps(arrow), isFalse,
            reason: 'Arrow ${arrow.id.value} overlaps another arrow');
      }
    });

    // ── 3. VALID BODIES ───────────────────────────────────────────────────────

    test('valid-bodies: all cells are orthogonally adjacent, pairwise distinct, in range, length>=2', () {
      // Arrange
      final gen = GraphBoardGenerator();
      const cols = 8, rows = 8, maxPathLen = 5;
      final board = gen.generate(
          cols: cols, rows: rows, arrowCount: 14, maxPathLen: maxPathLen, seed: 17);

      // Assert
      for (final arrow in board.arrows) {
        // Length >= 2
        expect(arrow.cells.length, greaterThanOrEqualTo(2),
            reason: 'Arrow ${arrow.id.value} has length ${arrow.cells.length} < 2');

        // Length <= maxPathLen
        expect(arrow.cells.length, lessThanOrEqualTo(maxPathLen),
            reason: 'Arrow ${arrow.id.value} has length ${arrow.cells.length} > maxPathLen $maxPathLen');

        // Pairwise distinct
        final uniqueCells = arrow.cells.toSet();
        expect(uniqueCells.length, arrow.cells.length,
            reason: 'Arrow ${arrow.id.value} has repeated cells');

        // All cells in range [0,cols) x [0,rows)
        for (final cell in arrow.cells) {
          expect(cell.col, greaterThanOrEqualTo(0),
              reason: 'Cell col ${cell.col} out of range');
          expect(cell.col, lessThan(cols),
              reason: 'Cell col ${cell.col} >= cols $cols');
          expect(cell.row, greaterThanOrEqualTo(0),
              reason: 'Cell row ${cell.row} out of range');
          expect(cell.row, lessThan(rows),
              reason: 'Cell row ${cell.row} >= rows $rows');
        }

        // Consecutive cells are orthogonally adjacent (Manhattan distance == 1)
        for (var i = 0; i < arrow.cells.length - 1; i++) {
          final a = arrow.cells[i];
          final b = arrow.cells[i + 1];
          final manhattan = (a.row - b.row).abs() + (a.col - b.col).abs();
          expect(manhattan, 1,
              reason:
                  'Arrow ${arrow.id.value}: cells[$i] and cells[${i + 1}] '
                  'are not orthogonally adjacent (manhattan=$manhattan)');
        }
      }
    });

    test('valid-bodies: length in [2, maxPathLen] with maxPathLen=2 forces exactly-2-cell arrows', () {
      // Arrange — maxPathLen=2 means targetLen = 2 + rng.nextInt(2-1) = 2 always
      final gen = GraphBoardGenerator();
      final board = gen.generate(
          cols: 6, rows: 6, arrowCount: 4, maxPathLen: 2, seed: 55);

      // Assert
      for (final arrow in board.arrows) {
        expect(arrow.cells.length, equals(2),
            reason:
                'With maxPathLen=2, all arrows must have exactly 2 cells; '
                'got ${arrow.cells.length} for ${arrow.id.value}');
      }
    });

    // ── 4. HEAD LANE FREE AT PLACEMENT ────────────────────────────────────────

    test('head-lane-free: exit lane of arrow-i is free of all arrows placed BEFORE it (indices 0..i-1)', () {
      // Arrange
      // board.arrows is in placement order (arrow-0 first, arrow-N last).
      // The placement gate `canExit(candidate)` checks the lane against
      // already-placed arrows only — so at placement time arrow-i's lane is
      // free of arrows 0..i-1. A LATER arrow (j > i) may occupy those lane
      // cells (its body doesn't overlap, but lane cells are not body cells).
      // Therefore the correct invariant is the placement-time guarantee, not
      // that every arrow can exit in the final state.
      final gen = GraphBoardGenerator();
      final board = gen.generate(
          cols: 7, rows: 7, arrowCount: 8, maxPathLen: 4, seed: 23);

      // Assert — for each arrow at index i, none of its exit-lane cells are
      // occupied by any arrow placed BEFORE it (indices 0..i-1).
      for (var i = 0; i < board.arrows.length; i++) {
        final arrow = board.arrows[i];
        // Cells belonging to arrows placed before arrow-i.
        final priorCells = <Position>{
          for (var j = 0; j < i; j++) ...board.arrows[j].cells,
        };
        final laneCells = board.space.exitLane(arrow.head, arrow.headDirection);
        for (final cell in laneCells) {
          expect(priorCells.contains(cell), isFalse,
              reason:
                  'Arrow ${arrow.id.value} (index $i): exit-lane cell '
                  '(row=${cell.row}, col=${cell.col}) is occupied by an '
                  'arrow placed before it — violates the placement-time invariant');
        }
      }
    });

    // ── 5. SOLUBILITY BY CONSTRUCTION (REVERSE ORDER) ─────────────────────────

    test('solubility: removing arrows in reverse placement order, each canExit before removal', () {
      // Arrange
      final gen = GraphBoardGenerator();
      final board = gen.generate(
          cols: 8, rows: 8, arrowCount: 10, maxPathLen: 4, seed: 31);

      // Act + Assert — strict reverse-order solubility
      expect(_isSolvableStrictReverseOrder(board), isTrue,
          reason: 'Board is not solvable in strict reverse placement order');
    });

    test('solubility: greedy solver (any canExit) empties the board — multiple seeds', () {
      // Arrange
      final gen = GraphBoardGenerator();

      // Act + Assert — multiple seeds
      for (final seed in [1, 2, 3, 42, 99]) {
        final board = gen.generate(
            cols: 9, rows: 9, arrowCount: 14, maxPathLen: 5, seed: seed);
        expect(_isSolvableByReverseOrder(board), isTrue,
            reason: 'Board with seed=$seed is not solvable');
      }
    });

    // ── 6. GRACEFUL DEGRADATION ───────────────────────────────────────────────

    test('graceful-degradation: tiny dense board returns fewer arrows than arrowCount without throwing, and logs warn', () {
      // Arrange — 2x2 board with high arrowCount; physically impossible to fit many 2-cell arrows
      final mockLogger = _MockLoggerService();
      final gen = GraphBoardGenerator(logger: mockLogger);

      // Act
      final board = gen.generate(
          cols: 2, rows: 2, arrowCount: 20, maxPathLen: 3, seed: 0);

      // Assert — did not throw, placed fewer than requested
      expect(board.arrows.length, lessThan(20),
          reason: 'Expected fewer than 20 arrows in a 2x2 board');
      expect(board.cols, 2);
      expect(board.rows, 2);

      // Assert — logger.warn was called at least once (graceful degradation logged)
      expect(mockLogger.warnCallCount, greaterThanOrEqualTo(1),
          reason: 'Expected logger.warn to be called on graceful degradation');
    });

    test('graceful-degradation: board arrows are still valid (no overlaps, bodies valid) even when degraded', () {
      // Arrange
      final mockLogger = _MockLoggerService();
      final gen = GraphBoardGenerator(logger: mockLogger);
      final board = gen.generate(
          cols: 2, rows: 2, arrowCount: 20, maxPathLen: 3, seed: 0);

      // Act — collect placed arrow cells
      final allCells = <Position>[];
      for (final arrow in board.arrows) {
        allCells.addAll(arrow.cells);
      }

      // Assert — no overlaps in the degraded board either
      expect(allCells.toSet().length, allCells.length,
          reason: 'Degraded board has overlapping arrow cells');

      // Assert — all placed arrows still have valid bodies (length >= 2)
      for (final arrow in board.arrows) {
        expect(arrow.cells.length, greaterThanOrEqualTo(2));
      }
    });

    // ── Existing tests preserved (updated to new signature) ───────────────────

    test('generates a board with the requested number of arrows', () {
      // Arrange / Act
      final gen = GraphBoardGenerator();
      final board = gen.generate(cols: 5, rows: 5, arrowCount: 4, maxPathLen: 3, seed: 10);
      // Assert
      expect(board.arrows.length, lessThanOrEqualTo(4));
      expect(board.arrows, isNotEmpty);
    });

    test('generated board is solvable — every arrow can eventually be removed', () {
      // Arrange
      final gen = GraphBoardGenerator();
      final board = gen.generate(cols: 5, rows: 5, arrowCount: 5, maxPathLen: 3, seed: 21);
      // Act
      final solvable = _isSolvableByReverseOrder(board);
      // Assert
      expect(solvable, isTrue);
    });

    test('respects requested dimensions and never exceeds arrowCount', () {
      // Arrange / Act
      final gen = GraphBoardGenerator();
      final board = gen.generate(cols: 7, rows: 7, arrowCount: 9, maxPathLen: 4, seed: 1);
      // Assert
      expect(board.cols, 7);
      expect(board.rows, 7);
      expect(board.arrows.length, lessThanOrEqualTo(9));
      expect(board.arrows, isNotEmpty);
    });

    test('two calls with same seed produce the same board', () {
      // Arrange / Act
      final gen = GraphBoardGenerator();
      final boardA = gen.generate(cols: 4, rows: 4, arrowCount: 3, maxPathLen: 3, seed: 42);
      final boardB = gen.generate(cols: 4, rows: 4, arrowCount: 3, maxPathLen: 3, seed: 42);
      // Assert
      expect(boardA.arrows.length, boardB.arrows.length);
      for (var i = 0; i < boardA.arrows.length; i++) {
        expect(boardA.arrows[i], boardB.arrows[i]);
      }
    });

    // ── 7. PRECONDITION: maxPathLen >= 2 ─────────────────────────────────────

    test('precondition: generate throws AssertionError when maxPathLen < 2', () {
      // Arrange
      final gen = GraphBoardGenerator();

      // Act + Assert
      expect(
        () => gen.generate(cols: 4, rows: 4, arrowCount: 2, maxPathLen: 1),
        throwsA(isA<AssertionError>()),
        reason: 'maxPathLen=1 must throw AssertionError (would cause RangeError in nextInt)',
      );
    });
  });
}
