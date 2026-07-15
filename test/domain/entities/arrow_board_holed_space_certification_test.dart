import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../support/holed_rect_space.dart';

/// Certificación OCP (ADR-0005 D2/D7): ArrowBoard funciona sobre un espacio
/// agujereado sin editar una sola línea de Arrow/ArrowBoard. Si este archivo
/// compila y pasa usando solo HoledRectSpace + la API pública existente, la
/// extensibilidad prometida por BoardSpace queda demostrada, no solo
/// documentada.
void main() {
  group('ArrowBoard sobre HoledRectSpace — certificación OCP', () {
    test('una flecha cuyo carril termina en el agujero puede salir', () {
      // Arrange: agujero en (2,4); flecha corta hacia la derecha desde (2,1).
      final space = HoledRectSpace(6, 6, holes: {Position(row: 2, col: 4)});
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 2, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow], space: space);

      // Act & Assert
      expect(board.canExit(arrow.id), isTrue);
    });

    test('una flecha cuyo carril hacia el agujero está bloqueado no puede salir', () {
      // Arrange: misma geometría, pero otra flecha ocupa la celda intermedia.
      final space = HoledRectSpace(6, 6, holes: {Position(row: 2, col: 4)});
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
