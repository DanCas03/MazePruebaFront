import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_direction_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  group('ArrowBoard.remountedOn invariante de dirección (front#124)', () {
    test('should_throw_when_new_space_lacks_the_head_direction', () {
      // Arrange: flecha con cabeza `left` (válida en rect) montada en RectSpace;
      // se re-monta sobre un HexSpace (que NO admite left/right). La celda del
      // centro del hex R=3 es (3,3), dentro de ambos espacios.
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 3, col: 3)],
        headDirection: Direction.left,
      );
      final board = ArrowBoard(arrows: [arrow], space: const RectSpace(7, 7));

      // Act + Assert
      expect(
        () => board.remountedOn(const HexSpace(3)),
        throwsA(isA<InvalidDirectionException>()),
      );
    });

    test('should_remount_when_new_space_keeps_the_head_direction', () {
      // Arrange: cabeza `up` (válida en hex) — la celda (3,3) es el centro.
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 3, col: 3)],
        headDirection: Direction.up,
      );
      final board = ArrowBoard(arrows: [arrow], space: const RectSpace(7, 7));

      // Act
      final remounted = board.remountedOn(const HexSpace(3));

      // Assert
      expect(remounted.space, const HexSpace(3));
    });
  });
}
