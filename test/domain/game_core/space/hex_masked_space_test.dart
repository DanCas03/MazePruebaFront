import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  group('HexMaskedSpace (front#124)', () {
    test('should_restrict_contains_and_cellCount_to_active_cells', () {
      // Arrange: hex R=1 (7 celdas) con solo 3 activas.
      final active = {
        Position(row: 1, col: 1), // centro
        Position(row: 1, col: 2), // downRight/ upRight vecino
        Position(row: 0, col: 1),
      };
      final masked = HexMaskedSpace(1, activeCells: active);

      // Assert
      expect(masked.cellCount, 3);
      expect(masked.contains(Position(row: 1, col: 1)), isTrue);
      // Dentro del hex pero fuera de la máscara => no contenida.
      expect(masked.contains(Position(row: 2, col: 0)), isFalse);
      // Fuera del hex y de la máscara => no contenida.
      expect(masked.contains(Position(row: 0, col: 0)), isFalse);
    });

    test('should_inherit_the_six_hex_directions', () {
      final masked =
          HexMaskedSpace(1, activeCells: {Position(row: 1, col: 1)});
      expect(masked.directions.toSet(), {
        Direction.up,
        Direction.down,
        Direction.upRight,
        Direction.downRight,
        Direction.upLeft,
        Direction.downLeft,
      });
    });

    test('should_yield_allCells_masked_in_canonical_order', () {
      final active = {
        Position(row: 1, col: 2),
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
      };
      final masked = HexMaskedSpace(1, activeCells: active);
      expect(masked.allCells.toList(), [
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ]);
    });

    test('should_treat_masked_cell_as_exit_boundary_in_exitLane', () {
      // Centro activo; su vecino downRight está enmascarado (inactivo) =>
      // el carril hacia downRight termina de inmediato (celda inactiva = frontera).
      final active = {
        Position(row: 1, col: 1), // centro
      };
      final masked = HexMaskedSpace(1, activeCells: active);
      final lane = masked.exitLane(Position(row: 1, col: 1), Direction.downRight);
      expect(lane, isEmpty); // el primer paso ya cae fuera de la máscara
    });
  });
}
