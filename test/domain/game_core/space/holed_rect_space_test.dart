import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../../support/board_space_contract_tests.dart';
import '../../../support/holed_rect_space.dart';

void main() {
  runBoardSpaceContractTests(
    'HoledRectSpace',
    () => HoledRectSpace(6, 8, holes: {Position(row: 5, col: 5)}),
    insideNearOrigin: Position(row: 0, col: 0),
    insideAwayFromEdges: Position(row: 2, col: 2),
  );

  group('HoledRectSpace — el agujero es frontera', () {
    test('contains es false para una celda agujereada dentro de los límites', () {
      final space = HoledRectSpace(6, 8, holes: {Position(row: 3, col: 3)});
      expect(space.contains(Position(row: 3, col: 3)), isFalse);
      expect(space.contains(Position(row: 3, col: 2)), isTrue);
    });

    test('exitLane termina antes del agujero, no lo incluye', () {
      final space = HoledRectSpace(6, 8, holes: {Position(row: 2, col: 4)});
      final lane = space.exitLane(Position(row: 2, col: 1), Direction.right);
      expect(lane, [
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
      ]);
      expect(lane, isNot(contains(Position(row: 2, col: 4))));
    });

    test('step hacia un agujero devuelve null, igual que hacia fuera del tablero', () {
      final space = HoledRectSpace(6, 8, holes: {Position(row: 1, col: 1)});
      expect(space.step(Position(row: 1, col: 0), Direction.right), isNull);
    });
  });
}
