import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';

void main() {
  group('Arrow', () {
    // Flecha horizontal: tail=(1,0) dir=right length=3 → ocupa (1,0),(1,1),(1,2)
    late Arrow sut;

    setUp(() {
      sut = Arrow(
        id: const ArrowId('a1'),
        tail: Position(row: 1, col: 0),
        direction: Direction.right,
        length: ArrowLength(3),
      );
    });

    test('head is the last cell in direction of movement', () {
      expect(sut.head, Position(row: 1, col: 2));
    });

    test('cells contains all occupied positions in order', () {
      expect(sut.cells, [
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ]);
    });

    test('exitPath for right arrow returns cells from head+1 to last col', () {
      // board 4 cols → exit path from col 3
      final path = sut.exitPath(4, 4);
      expect(path, [Position(row: 1, col: 3)]);
    });

    test('exitPath is empty when head is already at board edge', () {
      final edgeArrow = Arrow(
        id: const ArrowId('a2'),
        tail: Position(row: 1, col: 1),
        direction: Direction.right,
        length: ArrowLength(3), // head at col 3, board 4 cols → no path
      );
      expect(edgeArrow.exitPath(4, 4), isEmpty);
    });
  });
}
