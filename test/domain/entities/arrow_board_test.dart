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

    test('contains returns true when the arrow id is on the board', () {
      expect(sut.contains(const ArrowId('a1')), isTrue);
    });

    test('contains returns false when the arrow id is absent', () {
      expect(sut.contains(const ArrowId('ghost')), isFalse);
    });
  });

  // ── Task 2.1: arrowById y arrowAt ─────────────────────────────────────────
  // Board 4x4 con dos flechas para cubrir búsqueda por id y por celda.
  ArrowBoard _board2() => ArrowBoard(
        cols: 4,
        rows: 4,
        arrows: [
          // ocupa (0,0) y (0,1)
          Arrow(
            id: const ArrowId('arrow-0'),
            tail: Position(row: 0, col: 0),
            direction: Direction.right,
            length: ArrowLength(2),
          ),
          // ocupa (2,2) y (3,2)
          Arrow(
            id: const ArrowId('arrow-1'),
            tail: Position(row: 2, col: 2),
            direction: Direction.down,
            length: ArrowLength(2),
          ),
        ],
      );

  group('ArrowBoard.arrowById', () {
    test('devuelve la flecha presente', () {
      // Arrange
      final board = _board2();
      // Act
      final result = board.arrowById(const ArrowId('arrow-1'));
      // Assert
      expect(result?.id, const ArrowId('arrow-1'));
    });

    test('devuelve null si el id no existe', () {
      // Arrange
      final board = _board2();
      // Act
      final result = board.arrowById(const ArrowId('nope'));
      // Assert
      expect(result, isNull);
    });
  });

  group('ArrowBoard.arrowAt', () {
    test('devuelve la flecha que ocupa la celda', () {
      // Arrange
      final board = _board2();
      // Act
      final a = board.arrowAt(Position(row: 0, col: 1));
      final b = board.arrowAt(Position(row: 3, col: 2));
      // Assert
      expect(a?.id, const ArrowId('arrow-0'));
      expect(b?.id, const ArrowId('arrow-1'));
    });

    test('devuelve null en una celda vacía', () {
      // Arrange
      final board = _board2();
      // Act
      final result = board.arrowAt(Position(row: 1, col: 1));
      // Assert
      expect(result, isNull);
    });
  });
}
