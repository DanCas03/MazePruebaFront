import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_direction_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  group('RectSpace direcciones válidas y fail-fast (front#124)', () {
    test('should_expose_exactly_the_four_rect_directions_in_order', () {
      // Arrange
      const space = RectSpace(5, 5);

      // Act
      final dirs = space.directions.toList();

      // Assert
      expect(dirs, [
        Direction.up,
        Direction.down,
        Direction.left,
        Direction.right,
      ]);
    });

    test('should_throw_InvalidDirectionException_when_stepping_diagonal', () {
      // Arrange
      const space = RectSpace(5, 5);
      final center = Position(row: 2, col: 2);

      // Act + Assert
      for (final diagonal in [
        Direction.upLeft,
        Direction.upRight,
        Direction.downLeft,
        Direction.downRight,
      ]) {
        expect(
          () => space.step(center, diagonal),
          throwsA(isA<InvalidDirectionException>()),
          reason: '$diagonal no pertenece a RectSpace',
        );
      }
    });

    test('should_keep_returning_null_when_orthogonal_step_falls_outside', () {
      // Arrange
      const space = RectSpace(5, 5);

      // Act + Assert: dirección válida que cae fuera => null (no excepción)
      expect(space.step(Position(row: 0, col: 0), Direction.up), isNull);
      expect(space.step(Position(row: 0, col: 0), Direction.left), isNull);
    });
  });
}
