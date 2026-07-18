import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/direction_projection.dart';

void main() {
  const s = 0.8660254037844386; // sqrt(3)/2

  group('direction_projection — total sobre 8 valores (front#124)', () {
    test('should_project_flat_top_unit_vectors_for_all_eight_directions', () {
      expect(directionUnit(Direction.right).dx, closeTo(1, 1e-9));
      expect(directionUnit(Direction.right).dy, closeTo(0, 1e-9));
      expect(directionUnit(Direction.up).dy, closeTo(-1, 1e-9));
      expect(directionUnit(Direction.down).dy, closeTo(1, 1e-9));
      expect(directionUnit(Direction.left).dx, closeTo(-1, 1e-9));

      expect(directionUnit(Direction.upRight).dx, closeTo(s, 1e-9));
      expect(directionUnit(Direction.upRight).dy, closeTo(-0.5, 1e-9));
      expect(directionUnit(Direction.downRight).dx, closeTo(s, 1e-9));
      expect(directionUnit(Direction.downRight).dy, closeTo(0.5, 1e-9));
      expect(directionUnit(Direction.upLeft).dx, closeTo(-s, 1e-9));
      expect(directionUnit(Direction.upLeft).dy, closeTo(-0.5, 1e-9));
      expect(directionUnit(Direction.downLeft).dx, closeTo(-s, 1e-9));
      expect(directionUnit(Direction.downLeft).dy, closeTo(0.5, 1e-9));
    });

    test('should_keep_rect_angles_and_derive_coherent_diagonal_angles', () {
      // Rect intactos
      expect(directionAngle(Direction.right), 0.0);
      expect(directionAngle(Direction.left), math.pi);
      expect(directionAngle(Direction.down), math.pi / 2);
      expect(directionAngle(Direction.up), -math.pi / 2);
      // Diagonales coherentes con los vectores flat-top
      expect(directionAngle(Direction.upRight), closeTo(-math.pi / 6, 1e-9));
      expect(directionAngle(Direction.downRight), closeTo(math.pi / 6, 1e-9));
      expect(directionAngle(Direction.upLeft), closeTo(-5 * math.pi / 6, 1e-9));
      expect(directionAngle(Direction.downLeft), closeTo(5 * math.pi / 6, 1e-9));
    });

    test('should_keep_rect_cellsToEdge_and_defer_diagonals_to_render', () {
      final head = Position(row: 2, col: 3);
      // Rect intactos
      expect(cellsToEdge(head, Direction.right, cols: 8, rows: 8), 8 - 1 - 3);
      expect(cellsToEdge(head, Direction.left, cols: 8, rows: 8), 3);
      expect(cellsToEdge(head, Direction.down, cols: 8, rows: 8), 8 - 1 - 2);
      expect(cellsToEdge(head, Direction.up, cols: 8, rows: 8), 2);
      // Diagonales diferidas a front#126 => throw explícito
      for (final d in [
        Direction.upLeft,
        Direction.upRight,
        Direction.downLeft,
        Direction.downRight,
      ]) {
        expect(
          () => cellsToEdge(head, d, cols: 8, rows: 8),
          throwsA(isA<UnimplementedError>()),
        );
      }
    });
  });
}
