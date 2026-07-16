import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import '../../support/arrow_fixtures.dart';

/// Tablero 4×4 con dos flechas que juntas cubren un subconjunto de la caja:
///   a1: (0,0)-(0,1)  →  {(0,0),(0,1)}
///   a2: (2,1)-(2,2)  →  {(2,1),(2,2)}
/// La silueta es la unión de esas 4 celdas; el resto de la caja 4×4 queda fuera.
ArrowBoard _board() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        straightArrow(
          id: const ArrowId('a2'),
          tail: Position(row: 2, col: 1),
          direction: Direction.right,
          length: 2,
        ),
      ],
      space: RectSpace(4, 4),
    );

void main() {
  group('ArrowBoard.withSilhouetteSpace', () {
    test('replaces the space with a MaskedSpace over the union of arrow cells',
        () {
      // Arrange
      final board = _board();

      // Act
      final silhouette = board.withSilhouetteSpace();

      // Assert — máscara exacta = unión de las celdas de las flechas.
      expect(
        silhouette.space,
        MaskedSpace(4, 4, activeCells: {
          Position(row: 0, col: 0),
          Position(row: 0, col: 1),
          Position(row: 2, col: 1),
          Position(row: 2, col: 2),
        }),
      );
    });

    test('keeps the same arrows and bounding box (frame unchanged)', () {
      // Arrange
      final board = _board();

      // Act
      final silhouette = board.withSilhouetteSpace();

      // Assert
      expect(silhouette.arrows, board.arrows);
      expect(silhouette.cols, 4);
      expect(silhouette.rows, 4);
    });

    test('cells covered by an arrow are inside; uncovered box cells are outside',
        () {
      // Arrange / Act
      final space = _board().withSilhouetteSpace().space;

      // Assert — celda de flecha ⇒ dentro; celda de la caja sin flecha ⇒ fuera.
      expect(space.contains(Position(row: 0, col: 0)), isTrue);
      expect(space.contains(Position(row: 2, col: 2)), isTrue);
      expect(space.contains(Position(row: 3, col: 3)), isFalse);
      expect(space.contains(Position(row: 1, col: 0)), isFalse);
    });

    test('does not reduce solvability: a clear-path arrow can still exit', () {
      // Arrange — a1 sale por la derecha; su carril (0,2),(0,3) no lo cubre
      // ninguna flecha, así que la máscara lo corta y la salida sigue libre.
      final board = _board().withSilhouetteSpace();

      // Act / Assert
      expect(board.canExit(const ArrowId('a1')), isTrue);
      expect(board.canExit(const ArrowId('a2')), isTrue);
    });

    test('removeArrow preserves the masked space (the figure does not shrink)',
        () {
      // Arrange
      final board = _board().withSilhouetteSpace();
      final maskedSpace = board.space;

      // Act — retira una flecha; el espacio debe conservarse intacto.
      final after = board.removeArrow(const ArrowId('a1'));

      // Assert
      expect(after.space, maskedSpace);
    });
  });
}
