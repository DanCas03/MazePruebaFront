import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../../support/board_space_contract_tests.dart';

/// Todas las celdas de una caja cols×rows desde el origen, row-major.
Set<Position> _fullBox(int cols, int rows) => {
      for (var row = 0; row < rows; row++)
        for (var col = 0; col < cols; col++) Position(row: row, col: col),
    };

void main() {
  // Contrato compartido: un MaskedSpace de una caja 6×8 con una sola celda
  // enmascarada (5,5), lejos de las posiciones de muestra que el contrato usa.
  runBoardSpaceContractTests(
    'MaskedSpace',
    () => MaskedSpace(6, 8,
        activeCells: _fullBox(6, 8)..remove(Position(row: 5, col: 5))),
    insideNearOrigin: Position(row: 0, col: 0),
    insideAwayFromEdges: Position(row: 2, col: 2),
  );

  group('MaskedSpace — la celda enmascarada es frontera', () {
    test('contains = dentro-de-caja AND dentro-del-set', () {
      final space = MaskedSpace(6, 8,
          activeCells: _fullBox(6, 8)..remove(Position(row: 3, col: 3)));
      // Celda enmascarada dentro de la caja: no pertenece.
      expect(space.contains(Position(row: 3, col: 3)), isFalse);
      // Vecina activa: pertenece.
      expect(space.contains(Position(row: 3, col: 2)), isTrue);
      // Fuera de la caja: no pertenece.
      expect(space.contains(Position(row: 8, col: 0)), isFalse);
    });

    test('step hacia una celda enmascarada devuelve null (frontera)', () {
      final space = MaskedSpace(6, 8,
          activeCells: _fullBox(6, 8)..remove(Position(row: 1, col: 1)));
      expect(space.step(Position(row: 1, col: 0), Direction.right), isNull);
    });

    test('exitLane termina en el borde de la máscara, sin incluirla', () {
      final space = MaskedSpace(6, 8,
          activeCells: _fullBox(6, 8)..remove(Position(row: 2, col: 4)));
      final lane = space.exitLane(Position(row: 2, col: 1), Direction.right);
      expect(lane, [
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
      ]);
      expect(lane, isNot(contains(Position(row: 2, col: 4))));
    });

    test('allCells excluye las celdas enmascaradas y son el set activo', () {
      final masked = {Position(row: 0, col: 1), Position(row: 1, col: 1)};
      final space =
          MaskedSpace(2, 2, activeCells: _fullBox(2, 2)..removeAll(masked));
      expect(space.allCells.toList(), [
        Position(row: 0, col: 0),
        Position(row: 1, col: 0),
      ]);
      for (final cell in masked) {
        expect(space.allCells, isNot(contains(cell)));
      }
    });

    test('cellCount es el tamaño del set activo, no el área de la caja', () {
      final space = MaskedSpace(6, 8,
          activeCells: {Position(row: 0, col: 0), Position(row: 0, col: 1)});
      expect(space.cellCount, 2);
    });

    test('bounds es la caja completa cols×rows desde el origen', () {
      final space = MaskedSpace(6, 8,
          activeCells: {Position(row: 3, col: 3)});
      final box = space.bounds;
      expect(box.minRow, 0);
      expect(box.minCol, 0);
      expect(box.rows, 8);
      expect(box.cols, 6);
    });
  });
}
