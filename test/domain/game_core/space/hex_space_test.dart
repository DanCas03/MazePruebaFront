import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_direction_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  // Centro del hex de radio R está en (row=R, col=R) => q=0, r=0.
  group('HexSpace geometría flat-top (front#124)', () {
    test('should_expose_the_six_hex_directions', () {
      const hex = HexSpace(3);
      expect(hex.directions.toSet(), {
        Direction.up,
        Direction.down,
        Direction.upRight,
        Direction.downRight,
        Direction.upLeft,
        Direction.downLeft,
      });
      // NO incluye left/right
      expect(hex.directions.contains(Direction.left), isFalse);
      expect(hex.directions.contains(Direction.right), isFalse);
    });

    test('should_count_cells_as_3R2_plus_3R_plus_1_for_R_1_to_5', () {
      for (var r = 1; r <= 5; r++) {
        final hex = HexSpace(r);
        expect(hex.cellCount, 3 * r * r + 3 * r + 1, reason: 'R=$r');
        // allCells coincide en cuenta con cellCount
        expect(hex.allCells.length, hex.cellCount, reason: 'R=$r allCells');
      }
    });

    test('should_contain_center_and_ring_and_exclude_far_corner', () {
      const hex = HexSpace(2); // caja 5x5, centro (2,2)
      expect(hex.contains(Position(row: 2, col: 2)), isTrue); // q=0,r=0
      expect(hex.contains(Position(row: 2, col: 4)), isTrue); // q=2,r=0
      expect(hex.contains(Position(row: 0, col: 2)), isTrue); // q=0,r=-2
      // Esquina de la caja fuera del hex: (row=0,col=0) => q=-2,r=-2,|q+r|=4>2
      expect(hex.contains(Position(row: 0, col: 0)), isFalse);
      expect(hex.contains(Position(row: 4, col: 4)), isFalse);
    });

    test('should_step_in_all_six_directions_from_center', () {
      const hex = HexSpace(2);
      final c = Position(row: 2, col: 2);
      expect(hex.step(c, Direction.up), Position(row: 1, col: 2));
      expect(hex.step(c, Direction.down), Position(row: 3, col: 2));
      expect(hex.step(c, Direction.upRight), Position(row: 1, col: 3));
      expect(hex.step(c, Direction.downRight), Position(row: 2, col: 3));
      expect(hex.step(c, Direction.upLeft), Position(row: 2, col: 1));
      expect(hex.step(c, Direction.downLeft), Position(row: 3, col: 1));
    });

    test('should_return_null_when_step_crosses_the_hex_boundary', () {
      const hex = HexSpace(1); // caja 3x3, centro (1,1); anillo de 6 + centro = 7
      // Desde el borde superior hacia arriba cae fuera.
      final top = Position(row: 0, col: 1); // q=0, r=-1
      expect(hex.step(top, Direction.up), isNull);
    });

    test('should_return_null_via_contains_gate_when_step_lands_outside_hex',
        () {
      const hex = HexSpace(2); // caja 5x5, centro (2,2)
      // Caso principal: ambas coords resultantes son >=0 (el guard de
      // negativo NO dispara), pero la celda cae fuera del hexágono, así que
      // solo el gate `contains(next) ? next : null` puede devolver null.
      // (1,1) => q=-1,r=-1,|q+r|=2<=2 (dentro). up: (row-1,col) => (0,1)
      // => q=-1,r=-2,|q+r|=3>2 (fuera).
      expect(hex.step(Position(row: 1, col: 1), Direction.up), isNull);
      // Segundo caso, lado opuesto de la caja: (3,3) => q=1,r=1,|q+r|=2<=2
      // (dentro). down: (row+1,col) => (4,3) => q=1,r=2,|q+r|=3>2 (fuera).
      expect(hex.step(Position(row: 3, col: 3), Direction.down), isNull);
      // Disjunto col<0 del guard de negativo, para completar la cobertura:
      // (2,0) => q=-2,r=0,|q+r|=2<=2 (dentro). upLeft: (row,col-1) =>
      // nextCol=-1 => dispara el guard de negativo => null.
      expect(hex.step(Position(row: 2, col: 0), Direction.upLeft), isNull);
    });

    test('should_throw_when_stepping_left_or_right', () {
      const hex = HexSpace(2);
      final c = Position(row: 2, col: 2);
      expect(() => hex.step(c, Direction.left),
          throwsA(isA<InvalidDirectionException>()));
      expect(() => hex.step(c, Direction.right),
          throwsA(isA<InvalidDirectionException>()));
    });

    test('should_yield_allCells_in_canonical_row_major_order', () {
      const hex = HexSpace(1);
      final cells = hex.allCells.toList();
      // Orden row asc, luego col asc; filtrado por el hexágono.
      // R=1: filas 0..2. Fila0: q+r con row0 => r=-1 => cols con |q|<=1,|q-1|<=1
      //   => q in {0,1} => col in {1,2}. Fila1 (r=0): q in {-1,0,1} => col {0,1,2}.
      //   Fila2 (r=1): q in {-1,0} => col {0,1}.
      expect(cells, [
        Position(row: 0, col: 1),
        Position(row: 0, col: 2),
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
        Position(row: 2, col: 0),
        Position(row: 2, col: 1),
      ]);
    });

    test('should_report_bounds_as_2R_plus_1_square', () {
      const hex = HexSpace(3);
      final b = hex.bounds;
      expect(b.minRow, 0);
      expect(b.minCol, 0);
      expect(b.rows, 7);
      expect(b.cols, 7);
    });

    test('should_treat_boundary_as_exit_via_inherited_exitLane', () {
      const hex = HexSpace(1);
      // Desde el centro hacia arriba: una celda (borde) y luego fuera.
      final lane = hex.exitLane(Position(row: 1, col: 1), Direction.up);
      expect(lane, [Position(row: 0, col: 1)]);
    });

    test('should_answer_areAdjacent_using_hex_neighbours', () {
      const hex = HexSpace(2);
      final c = Position(row: 2, col: 2);
      expect(hex.areAdjacent(c, Position(row: 1, col: 3)), isTrue); // upRight
      expect(hex.areAdjacent(c, Position(row: 2, col: 2)), isFalse); // sí mismo
    });
  });
}
