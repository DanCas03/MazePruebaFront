import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_direction_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  group('Level invariante headDir ∈ space.directions (front#124)', () {
    test('should_throw_when_a_rect_level_has_a_diagonal_head_direction', () {
      // Arrange: flecha con cabeza diagonal sobre un RectSpace (solo 4 dirs).
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 1, col: 1)],
        headDirection: Direction.upLeft,
      );
      final board = ArrowBoard(arrows: [arrow], space: const RectSpace(5, 5));

      // Act + Assert
      expect(
        () => Level(id: LevelId('lvl-1'), board: board),
        throwsA(isA<InvalidDirectionException>()),
      );
    });

    test('should_build_when_all_head_directions_belong_to_the_space', () {
      // Arrange
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 1, col: 1)],
        headDirection: Direction.up,
      );
      final board = ArrowBoard(arrows: [arrow], space: const RectSpace(5, 5));

      // Act
      final level = Level(id: LevelId('lvl-1'), board: board);

      // Assert
      expect(level.board.arrows.single.headDirection, Direction.up);
    });
  });
}
