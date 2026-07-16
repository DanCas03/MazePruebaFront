import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Certificación OCP (ADR-0005 D2/D7): ArrowBoard funciona sobre el espacio de
/// PRODUCCIÓN [MaskedSpace] sin editar una sola línea de Arrow/ArrowBoard. Es el
/// gemelo de la certificación de HoledRectSpace, pero sobre la geometría real
/// que renderizará siluetas: si compila y pasa usando solo MaskedSpace + la API
/// pública existente, la extensibilidad prometida por BoardSpace queda
/// demostrada también para la máscara de producción.
Set<Position> _fullBox(int cols, int rows) => {
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++) Position(row: row, col: col),
    };

void main() {
  group('ArrowBoard sobre MaskedSpace — certificación OCP', () {
    test('una flecha cuyo carril termina en el borde de la máscara puede salir',
        () {
      // Arrange: celda (2,4) enmascarada; flecha corta a la derecha desde (2,1).
      final space = MaskedSpace(6, 6,
          activeCells: _fullBox(6, 6)..remove(Position(row: 2, col: 4)));
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 2, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow], space: space);

      // Act & Assert
      expect(board.canExit(arrow.id), isTrue);
    });

    test('una flecha bloqueada hacia el borde de la máscara no puede salir', () {
      // Arrange: misma geometría, pero otra flecha ocupa la celda intermedia.
      final space = MaskedSpace(6, 6,
          activeCells: _fullBox(6, 6)..remove(Position(row: 2, col: 4)));
      final blocker = Arrow(
        id: ArrowId('blocker'),
        cells: [Position(row: 2, col: 3)],
        headDirection: Direction.down,
      );
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 2, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow, blocker], space: space);

      // Act & Assert
      expect(board.canExit(arrow.id), isFalse);
    });
  });
}
