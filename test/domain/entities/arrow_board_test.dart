import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

Arrow _makeArrow({required String id, required int row, required int col,
    Direction dir = Direction.right, int len = 2}) =>
    straightArrow(id: ArrowId(id), tail: Position(row: row, col: col),
        direction: dir, length: len);

void main() {
  group('ArrowBoard', () {
    // Board 4x4 con una sola flecha que puede salir por la derecha
    late ArrowBoard sut;
    late Arrow arrow;

    setUp(() {
      arrow = _makeArrow(id: 'a1', row: 0, col: 0, dir: Direction.right, len: 2);
      sut = ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
    });

    test('isCleared is false when board has arrows', () {
      expect(sut.isCleared, isFalse);
    });

    test('canExit returns true when exit path is free', () {
      expect(sut.canExit(const ArrowId('a1')), isTrue);
    });

    test('canExit returns false when another arrow blocks the exit path', () {
      final blocker = _makeArrow(id: 'b1', row: 0, col: 2, dir: Direction.down, len: 1);
      final board = ArrowBoard(arrows: [arrow, blocker], space: RectSpace(4, 4));
      expect(board.canExit(const ArrowId('a1')), isFalse);
    });

    // Reubicado desde arrow_test.dart (front#73): antes probaba Arrow.exitPath;
    // ahora prueba que canExit lee headDirection (vía space.exitLane), no el
    // último segmento del cuerpo. La geometría del carril ya está probada una
    // sola vez a nivel de espacio (rect_space_test.dart).
    test('canExit sigue headDirection (right), no el último segmento del cuerpo (up)', () {
      // Arrange: cuerpo doblado que llega a la cabeza viniendo de "arriba",
      // pero headDirection es "right". Si canExit leyera el último segmento
      // del cuerpo en vez de headDirection, el carril iría hacia (0,2)
      // -ocupado por decoy- y devolvería false en lugar de true.
      final space = RectSpace(6, 6);
      final decoy = Arrow(
        id: ArrowId('decoy'),
        cells: [Position(row: 0, col: 2)],
        headDirection: Direction.up,
      );
      final bent = Arrow(
        id: ArrowId('bent'),
        cells: [
          Position(row: 3, col: 2),
          Position(row: 2, col: 2),
          Position(row: 1, col: 2),
        ],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [bent, decoy], space: space);

      // Act & Assert
      expect(board.canExit(bent.id), isTrue);
    });

    test('removeArrow returns new board without that arrow', () {
      final newBoard = sut.removeArrow(const ArrowId('a1'));
      expect(newBoard.isCleared, isTrue);
    });

    test('isCleared is true when board has no arrows', () {
      final empty = ArrowBoard(arrows: const [], space: RectSpace(4, 4));
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
  ArrowBoard board2() => ArrowBoard(
        space: RectSpace(4, 4),
        arrows: [
          // ocupa (0,0) y (0,1)
          straightArrow(
            id: const ArrowId('arrow-0'),
            tail: Position(row: 0, col: 0),
            direction: Direction.right,
            length: 2,
          ),
          // ocupa (2,2) y (3,2)
          straightArrow(
            id: const ArrowId('arrow-1'),
            tail: Position(row: 2, col: 2),
            direction: Direction.down,
            length: 2,
          ),
        ],
      );

  group('ArrowBoard.arrowById', () {
    test('devuelve la flecha presente', () {
      // Arrange
      final board = board2();
      // Act
      final result = board.arrowById(const ArrowId('arrow-1'));
      // Assert
      expect(result?.id, const ArrowId('arrow-1'));
    });

    test('devuelve null si el id no existe', () {
      // Arrange
      final board = board2();
      // Act
      final result = board.arrowById(const ArrowId('nope'));
      // Assert
      expect(result, isNull);
    });
  });

  group('ArrowBoard.arrowAt', () {
    test('devuelve la flecha que ocupa la celda', () {
      // Arrange
      final board = board2();
      // Act
      final a = board.arrowAt(Position(row: 0, col: 1));
      final b = board.arrowAt(Position(row: 3, col: 2));
      // Assert
      expect(a?.id, const ArrowId('arrow-0'));
      expect(b?.id, const ArrowId('arrow-1'));
    });

    test('devuelve null en una celda vacía', () {
      // Arrange
      final board = board2();
      // Act
      final result = board.arrowAt(Position(row: 1, col: 1));
      // Assert
      expect(result, isNull);
    });
  });
}
