import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

// ---------------------------------------------------------------------------
// Naive reference implementation of canExit (pre-#64 semantics): rebuilds the
// "occupied excluding own id" set on every call. The cached implementation in
// ArrowBoard must be functionally equivalent to this oracle.
// ---------------------------------------------------------------------------
bool _naiveCanExit(ArrowBoard board, ArrowId id) {
  final arrow = board.arrowById(id);
  if (arrow == null) return false;
  final occupied = <Position>{
    for (final a in board.arrows)
      if (a.id != id) ...a.cells,
  };
  return board.space.exitLane(arrow.head, arrow.headDirection).every((p) => !occupied.contains(p));
}

/// Builds a random small board with self-avoiding, non-overlapping bent
/// arrows. headDirection is chosen independently of the body shape, so an
/// arrow's exit lane may cross its OWN body (the folded-snake subtlety) or
/// another arrow's body — exercising both canExit outcomes.
ArrowBoard _randomBoard(Random rng, {required int cols, required int rows}) {
  final occupied = <Position>{};
  final arrows = <Arrow>[];
  final arrowTarget = 2 + rng.nextInt(5); // 2..6 arrows
  var attempts = 0;

  while (arrows.length < arrowTarget && attempts < 60) {
    attempts++;
    final start =
        Position(row: rng.nextInt(rows), col: rng.nextInt(cols));
    if (occupied.contains(start)) continue;

    final body = <Position>[start];
    final taken = <Position>{...occupied, start};
    final targetLen = 2 + rng.nextInt(4); // 2..5 cells
    var cursor = start;
    while (body.length < targetLen) {
      final neighbors = <Position>[
        if (cursor.row > 0) Position(row: cursor.row - 1, col: cursor.col),
        if (cursor.row < rows - 1) Position(row: cursor.row + 1, col: cursor.col),
        if (cursor.col > 0) Position(row: cursor.row, col: cursor.col - 1),
        if (cursor.col < cols - 1) Position(row: cursor.row, col: cursor.col + 1),
      ].where((p) => !taken.contains(p)).toList();
      if (neighbors.isEmpty) break;
      final next = neighbors[rng.nextInt(neighbors.length)];
      body.add(next);
      taken.add(next);
      cursor = next;
    }
    if (body.length < 2) continue;

    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    arrows.add(Arrow(
      id: ArrowId('arrow-${arrows.length}'),
      cells: body,
      headDirection: dir,
    ));
    occupied.addAll(body);
  }

  return ArrowBoard(arrows: arrows, space: RectSpace(cols, rows));
}

void main() {
  // ── Regression (#64): folded snake stepping on its own exit lane ──────────
  group('ArrowBoard.canExit — folded snake over its own lane', () {
    test('exits when the only cells on the exit lane belong to its own body', () {
      // Arrange — 5x5 board; path (1,2)→(2,2)→(2,1), head (2,1), exits RIGHT.
      // Exit lane = (2,2),(2,3),(2,4); own body cell (2,2) sits on the lane.
      final snake = Arrow(
        id: const ArrowId('snake'),
        cells: [
          Position(row: 1, col: 2),
          Position(row: 2, col: 2),
          Position(row: 2, col: 1),
        ],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [snake], space: RectSpace(5, 5));

      // Act
      final result = board.canExit(const ArrowId('snake'));

      // Assert — the body retracts along its own path; own cells never block.
      expect(result, isTrue,
          reason: 'A folded snake whose body sits on its own exit lane must exit');
    });

    test('is still blocked when ANOTHER arrow occupies the exit lane', () {
      // Arrange — same folded snake, plus a blocker on lane cell (2,3).
      final snake = Arrow(
        id: const ArrowId('snake'),
        cells: [
          Position(row: 1, col: 2),
          Position(row: 2, col: 2),
          Position(row: 2, col: 1),
        ],
        headDirection: Direction.right,
      );
      final blocker = straightArrow(
        id: const ArrowId('blocker'),
        tail: Position(row: 3, col: 3),
        direction: Direction.up,
        length: 2, // occupies (3,3) and (2,3)
      );
      final board = ArrowBoard(arrows: [snake, blocker], space: RectSpace(5, 5));

      // Act
      final blocked = board.canExit(const ArrowId('snake'));

      // Assert
      expect(blocked, isFalse,
          reason: 'Foreign cells on the lane must still block the exit');
    });

    test('exits after removing the blocker (fresh instance recomputes its cache)', () {
      // Arrange — blocked board from the previous scenario.
      final snake = Arrow(
        id: const ArrowId('snake'),
        cells: [
          Position(row: 1, col: 2),
          Position(row: 2, col: 2),
          Position(row: 2, col: 1),
        ],
        headDirection: Direction.right,
      );
      final blocker = straightArrow(
        id: const ArrowId('blocker'),
        tail: Position(row: 3, col: 3),
        direction: Direction.up,
        length: 2,
      );
      final board = ArrowBoard(arrows: [snake, blocker], space: RectSpace(5, 5));

      // Act — removeArrow returns a NEW immutable instance (new lazy cache).
      final after = board.removeArrow(const ArrowId('blocker'));

      // Assert — old instance stays blocked; new instance can exit.
      expect(board.canExit(const ArrowId('snake')), isFalse);
      expect(after.canExit(const ArrowId('snake')), isTrue);
    });
  });

  // ── Property-style (#64): cached canExit ≡ naive canExit ──────────────────
  group('ArrowBoard.canExit — cached vs naive equivalence', () {
    test('matches the naive implementation on ~200 random small boards', () {
      // Arrange — deterministic seed so failures are reproducible.
      final rng = Random(64);

      for (var i = 0; i < 200; i++) {
        final cols = 3 + rng.nextInt(5); // 3..7
        final rows = 3 + rng.nextInt(5); // 3..7
        final board = _randomBoard(rng, cols: cols, rows: rows);

        // Act + Assert — every arrow id, plus an id absent from the board.
        for (final arrow in board.arrows) {
          expect(
            board.canExit(arrow.id),
            _naiveCanExit(board, arrow.id),
            reason: 'Board $i (${cols}x$rows): cached canExit(${arrow.id.value}) '
                'diverges from naive implementation',
          );
        }
        expect(board.canExit(const ArrowId('ghost')),
            _naiveCanExit(board, const ArrowId('ghost')),
            reason: 'Board $i: absent id must behave identically');

        // Also after a removal, so the fresh instance's lazy cache is hit.
        if (board.arrows.isNotEmpty) {
          final removed = board.arrows[rng.nextInt(board.arrows.length)].id;
          final after = board.removeArrow(removed);
          for (final arrow in after.arrows) {
            expect(
              after.canExit(arrow.id),
              _naiveCanExit(after, arrow.id),
              reason: 'Board $i after removeArrow(${removed.value}): cached '
                  'canExit(${arrow.id.value}) diverges from naive',
            );
          }
        }
      }
    });
  });
}
