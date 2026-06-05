import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  // Tablero 3x1:  [A]→ [ ] [B]→   (A en col0, B en col2, ambos miran a la derecha)
  Arrow arrowA() => const Arrow(
        id: ArrowId(0),
        tail: Position(x: 0, y: 0),
        direction: Direction.right,
        length: ArrowLength(1),
        colorIndex: 0,
      );
  Arrow arrowB() => const Arrow(
        id: ArrowId(1),
        tail: Position(x: 2, y: 0),
        direction: Direction.right,
        length: ArrowLength(1),
        colorIndex: 1,
      );

  ArrowBoard buildBoard() =>
      ArrowBoard(width: 3, height: 1, arrows: [arrowA(), arrowB()]);

  test('una flecha bloqueada por otra en su recorrido no puede salir', () {
    // Arrange
    final board = buildBoard();

    // Act / Assert
    // B tiene el borde justo a su derecha: recorrido vacío ⇒ puede salir.
    expect(board.canExit(board.findById(const ArrowId(1))!), isTrue);
    // A tiene a B en su recorrido (col2) ⇒ bloqueada.
    expect(board.canExit(board.findById(const ArrowId(0))!), isFalse);
  });

  test('al sacar la flecha que bloquea, la otra queda liberada', () {
    // Arrange
    final board = buildBoard();

    // Act
    board.removeArrow(const ArrowId(1)); // sacamos B

    // Assert
    expect(board.canExit(board.findById(const ArrowId(0))!), isTrue);
    expect(board.remaining, equals(1));
  });

  test('sacar todas las flechas limpia el tablero', () {
    // Arrange
    final board = buildBoard();

    // Act
    board.removeArrow(const ArrowId(1));
    board.removeArrow(const ArrowId(0));

    // Assert
    expect(board.isCleared, isTrue);
  });

  test('arrowAt identifica la flecha que ocupa una celda', () {
    // Arrange
    final board = buildBoard();

    // Act
    final at0 = board.arrowAt(const Position(x: 0, y: 0));
    final at1 = board.arrowAt(const Position(x: 1, y: 0));

    // Assert
    expect(at0?.id, equals(const ArrowId(0)));
    expect(at1, isNull); // celda central vacía
  });
}
