import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';

Arrow _makeArrow({required String id, required int row, required int col,
    Direction dir = Direction.right, int len = 2}) =>
    Arrow(id: ArrowId(id), tail: Position(row: row, col: col),
        direction: dir, length: ArrowLength(len));

void main() {
  group('ArrowBoard', () {
    // Board 4x4 con una sola flecha que puede salir por la derecha
    late ArrowBoard sut;
    late Arrow arrow;

    setUp(() {
      arrow = _makeArrow(id: 'a1', row: 0, col: 0, dir: Direction.right, len: 2);
      sut = ArrowBoard(arrows: [arrow], cols: 4, rows: 4);
    });

    test('isCleared is false when board has arrows', () {
      expect(sut.isCleared, isFalse);
    });

    test('canExit returns true when exit path is free', () {
      expect(sut.canExit(const ArrowId('a1')), isTrue);
    });

    test('canExit returns false when another arrow blocks the exit path', () {
      final blocker = _makeArrow(id: 'b1', row: 0, col: 2, dir: Direction.down, len: 1);
      final board = ArrowBoard(arrows: [arrow, blocker], cols: 4, rows: 4);
      expect(board.canExit(const ArrowId('a1')), isFalse);
    });

    test('removeArrow returns new board without that arrow', () {
      final newBoard = sut.removeArrow(const ArrowId('a1'));
      expect(newBoard.isCleared, isTrue);
    });

    test('isCleared is true when board has no arrows', () {
      final empty = ArrowBoard(arrows: const [], cols: 4, rows: 4);
      expect(empty.isCleared, isTrue);
    });
  });
}
