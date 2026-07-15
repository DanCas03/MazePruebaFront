import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../../support/board_space_contract_tests.dart';

void main() {
  runBoardSpaceContractTests(
    'RectSpace',
    () => RectSpace(6, 8),
    insideNearOrigin: Position(row: 0, col: 0),
    insideAwayFromEdges: Position(row: 3, col: 3),
  );

  group('RectSpace — geometría rectangular específica', () {
    test('contains es false para coordenadas fuera de cols/rows', () {
      final space = RectSpace(4, 4);
      expect(space.contains(Position(row: 0, col: 4)), isFalse);
      expect(space.contains(Position(row: 4, col: 0)), isFalse);
    });

    test('directions expone las 4 direcciones cerradas', () {
      final space = RectSpace(4, 4);
      expect(space.directions, containsAll(Direction.values));
      expect(space.directions.length, 4);
    });

    test('cellCount es cols * rows', () {
      expect(RectSpace(6, 8).cellCount, 48);
    });

    test('allCells enumera exactamente cols*rows celdas únicas dentro del espacio', () {
      final space = RectSpace(3, 2);
      final cells = space.allCells.toSet();
      expect(cells.length, 6);
      expect(cells.every(space.contains), isTrue);
    });

    test('exitLane hacia la derecha desde el borde izquierdo cruza todo el ancho', () {
      final space = RectSpace(5, 5);
      final lane = space.exitLane(Position(row: 2, col: 0), Direction.right);
      expect(lane, [
        Position(row: 2, col: 1),
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
        Position(row: 2, col: 4),
      ]);
    });

    test('exitLane hacia arriba desde el borde inferior cruza toda la altura', () {
      final space = RectSpace(5, 5);
      final lane = space.exitLane(Position(row: 4, col: 1), Direction.up);
      expect(lane, [
        Position(row: 3, col: 1),
        Position(row: 2, col: 1),
        Position(row: 1, col: 1),
        Position(row: 0, col: 1),
      ]);
    });

    test('exitLane está vacío cuando la cabeza ya está en la frontera (cada dirección)', () {
      final space = RectSpace(4, 4);
      expect(space.exitLane(Position(row: 0, col: 3), Direction.right), isEmpty);
      expect(space.exitLane(Position(row: 0, col: 0), Direction.left), isEmpty);
      expect(space.exitLane(Position(row: 3, col: 0), Direction.down), isEmpty);
      expect(space.exitLane(Position(row: 0, col: 0), Direction.up), isEmpty);
    });

    test('dos RectSpace con las mismas dimensiones son iguales por valor', () {
      expect(RectSpace(6, 8), equals(RectSpace(6, 8)));
      expect(RectSpace(6, 8), isNot(equals(RectSpace(8, 6))));
    });
  });
}
