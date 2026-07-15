import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/board_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Suite de contrato compartida (ADR-0005 D7): cualquier [BoardSpace]
/// correcto debe cumplirla. Se corre contra RectSpace (Task 2) y contra
/// HoledRectSpace (Task 3, certificación OCP) sin que este código cambie —
/// solo el espacio bajo prueba y las posiciones de muestra que el llamador
/// garantiza libres de agujeros.
void runBoardSpaceContractTests(
  String label,
  BoardSpace Function() build, {
  required Position insideNearOrigin,
  required Position insideAwayFromEdges,
}) {
  group('BoardSpace contract — $label', () {
    test('contains es true dentro del espacio y false lejos de sus límites', () {
      final space = build();
      expect(space.contains(insideNearOrigin), isTrue);
      expect(space.contains(Position(row: 10000, col: 10000)), isFalse);
    });

    test('step devuelve la celda vecina cuando cae dentro del espacio', () {
      final space = build();
      final next = space.step(insideAwayFromEdges, Direction.right);
      expect(next, isNotNull);
      expect(next, isNot(equals(insideAwayFromEdges)));
      expect(space.contains(next!), isTrue);
    });

    test('step devuelve null cuando la vecina cae fuera del espacio', () {
      final space = build();
      final origin = Position(row: 0, col: 0);
      expect(space.step(origin, Direction.up), isNull);
      expect(space.step(origin, Direction.left), isNull);
    });

    test('areAdjacent es true solo para vecinos alcanzables por step', () {
      final space = build();
      final next = space.step(insideAwayFromEdges, Direction.down);
      expect(next, isNotNull);
      expect(space.areAdjacent(insideAwayFromEdges, next!), isTrue);
      expect(space.areAdjacent(insideAwayFromEdges, insideAwayFromEdges), isFalse);
    });

    test('exitLane excluye la cabeza y termina en la frontera', () {
      final space = build();
      final lane = space.exitLane(insideAwayFromEdges, Direction.right);
      expect(lane, isNot(contains(insideAwayFromEdges)));
      expect(lane, isNotEmpty);
      expect(space.step(lane.last, Direction.right), isNull);
    });

    test('allCells está en orden canónico row-major (row asc, col asc)', () {
      final space = build();
      final cells = space.allCells.toList();
      final sorted = [...cells]
        ..sort((a, b) {
          final byRow = a.row.compareTo(b.row);
          return byRow != 0 ? byRow : a.col.compareTo(b.col);
        });
      expect(cells, equals(sorted));
    });

    // Fase 1 (#85): la caja envolvente debe contener TODA celda del espacio.
    // Invariante universal (no exige que la caja sea ajustada: un espacio puede
    // declararla mayor que el span de sus celdas).
    test('bounds contiene todas las celdas del espacio', () {
      final space = build();
      final box = space.bounds;
      for (final cell in space.allCells) {
        expect(box.contains(cell), isTrue,
            reason: 'la caja $box debe contener $cell');
      }
    });
  });
}
