import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/band_layout.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

// ---------------------------------------------------------------------------
// GUARDIAN of the density fix (spec 2026-07-15-generator-band-density-design.md).
//
// The CURRENT GraphBoardGenerator concentrates arrows on the perimeter and
// leaves the interior a desert. Test 1 below encodes the DESIRED post-fix
// property (interior gets a fair share of the arrows) and is EXPECTED TO FAIL
// against the current generator — this RED state is intentional. It will turn
// GREEN once the generator is reworked to spread arrows across the concentric
// bands. Do NOT modify production code to satisfy it prematurely.
//
// Test 2 is a structural invariant (non-empty + no overlaps) that must hold
// both before AND after the fix; it guards against regressions in the rework.
// ---------------------------------------------------------------------------

/// Union of every cell occupied by any arrow on [board].
Set<Position> _occupiedCells(ArrowBoard board) {
  final occupied = <Position>{};
  for (final arrow in board.arrows) {
    occupied.addAll(arrow.cells);
  }
  return occupied;
}

void main() {
  const seeds = [11, 22, 33, 44, 55];
  // Tablero grande y denso: es donde el spec sitúa el anillo perimetral. En
  // 50×50 con 200 flechas el generador actual mide avg(interior/global) ≈ 0.47
  // (RED). Configs pequeñas/poco densas (p. ej. 20×20/60) no dejan el interior
  // desierto y no exponen el bug (avg ≈ 0.70, falso verde).
  const cols = 50;
  const rows = 50;
  const totalCells = cols * rows; // 2500

  ArrowBoard generateForSeed(int seed) {
    return GraphBoardGenerator().generate(
      cols: cols,
      rows: rows,
      arrowCount: 200,
      maxPathLen: 5,
      seed: seed,
    );
  }

  group('GraphBoardGenerator density (band guardian)', () {
    test(
        'interior band is filled at a fair rate relative to the whole board '
        '(avg ratio >= 0.6)', () {
      // Arrange
      final bands = concentricBands(cols: cols, rows: rows);
      final band0 = bands[0].toSet(); // index 0 = most interior band
      expect(band0, isNotEmpty,
          reason: 'interior band must have cells to measure density against');

      // Act
      final ratios = <double>[];
      for (final seed in seeds) {
        final board = generateForSeed(seed);
        final occupied = _occupiedCells(board);

        final interiorHits = occupied.intersection(band0).length;
        final interiorDensity = interiorHits / band0.length;
        final globalDensity = occupied.length / totalCells;

        // Guard against a division by zero when the board came out empty.
        final ratio = globalDensity == 0 ? 0.0 : interiorDensity / globalDensity;
        ratios.add(ratio);
      }
      final avgRatio =
          ratios.reduce((a, b) => a + b) / ratios.length;

      // Assert
      expect(avgRatio, greaterThanOrEqualTo(0.6),
          reason: 'interior should receive at least ~60% of the global cell '
              'density on average across seeds; current generator leaves the '
              'interior a desert. Measured avg ratio: $avgRatio '
              '(per-seed: $ratios)');
    });

    test('every board is non-empty and has no overlapping arrows', () {
      for (final seed in seeds) {
        // Arrange & Act
        final board = generateForSeed(seed);
        final occupied = _occupiedCells(board);
        final totalArrowCells =
            board.arrows.fold<int>(0, (sum, a) => sum + a.cells.length);

        // Assert
        expect(board.arrows, isNotEmpty,
            reason: 'seed $seed produced an empty board');
        expect(totalArrowCells, equals(occupied.length),
            reason: 'seed $seed has overlapping arrows: sum of arrow cell '
                'counts ($totalArrowCells) != size of occupied union '
                '(${occupied.length})');
      }
    });
  });
}
