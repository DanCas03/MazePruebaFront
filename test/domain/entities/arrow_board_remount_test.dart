import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_arrow_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

// Task 3 (#118): seam de montaje — mover un ArrowBoard existente a un
// BoardSpace DISTINTO conservando el mismo contenido de flechas. El brief
// original describía la validación como "invariantes del constructor de
// ArrowBoard re-ejecutados", pero el constructor es const con cuerpo vacío
// (sin asserts) — mantenerlo const es interfaz pública documentada (caché de
// Expando en arrow_board.dart, construcción const en
// candidate_producer_test.dart:98) y validar ahí añadiría un paso O(celdas) a
// CADA construcción, incluida `removeArrow` en cada movimiento de la partida.
// `remountedOn` valida localmente en su lugar.
Set<Position> _fullBox(int cols, int rows) => {
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++) Position(row: row, col: col),
    };

void main() {
  group('ArrowBoard.remountedOn', () {
    test('remonta a un MaskedSpace que contiene todas las flechas: mismas '
        'flechas, espacio nuevo', () {
      // Arrange: board 4x4 con una flecha, y un MaskedSpace 4x4 sin agujeros
      // (contiene toda la caja, por lo tanto contiene la flecha).
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
      final newSpace = MaskedSpace(4, 4, activeCells: _fullBox(4, 4));

      // Act
      final remounted = board.remountedOn(newSpace);

      // Assert
      expect(remounted.arrows, same(board.arrows));
      expect(remounted.space, same(newSpace));
    });

    test('remonta a un espacio que EXCLUYE una celda de una flecha: lanza '
        'InvalidArrowException', () {
      // Arrange: la flecha ocupa (0,1), pero la máscara nueva la excluye.
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
      final excludingSpace = MaskedSpace(4, 4,
          activeCells: _fullBox(4, 4)..remove(Position(row: 0, col: 1)));

      // Act & Assert
      expect(
        () => board.remountedOn(excludingSpace),
        throwsA(isA<InvalidArrowException>()),
      );
    });

    test('remontar preserva la igualdad de las flechas (Equatable)', () {
      // Arrange
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
      final newSpace = MaskedSpace(4, 4, activeCells: _fullBox(4, 4));

      // Act
      final remounted = board.remountedOn(newSpace);

      // Assert
      expect(remounted.arrows.single, equals(arrow));
    });
  });
}
