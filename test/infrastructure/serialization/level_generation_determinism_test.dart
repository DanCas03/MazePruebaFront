import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato de reproducibilidad del script de generación de candidatos
/// (front#1: "same seed => same JSON"). Se prueba al nivel de las piezas que el
/// script usa —GraphBoardGenerator + LevelJsonEncoder— sin importar nada de
/// tool/, para que el criterio quede fijado como contrato en las unidades
/// reutilizables y no en el runner.
void main() {
  group('Level generation determinism', () {
    const cols = 8;
    const rows = 11;
    const arrowCount = 9;
    const maxPathLen = 5;

    test(
        'should_produce_identical_json_when_generating_twice_with_same_seed',
        () {
      // Arrange
      final generator = GraphBoardGenerator();
      const encoder = LevelJsonEncoder();
      const seed = 302;
      const levelId = 'cand-t3-s302';

      // Act
      final firstBoard = generator.generate(
        cols: cols,
        rows: rows,
        arrowCount: arrowCount,
        maxPathLen: maxPathLen,
        seed: seed,
      );
      final secondBoard = generator.generate(
        cols: cols,
        rows: rows,
        arrowCount: arrowCount,
        maxPathLen: maxPathLen,
        seed: seed,
      );
      final firstJson = encoder.encode(levelId: levelId, board: firstBoard);
      final secondJson = encoder.encode(levelId: levelId, board: secondBoard);

      // Assert
      expect(secondJson, equals(firstJson));
    });

    test('should_produce_different_json_when_seeds_differ', () {
      // Arrange
      final generator = GraphBoardGenerator();
      const encoder = LevelJsonEncoder();
      const levelId = 'cand-seed-diff';

      // Act
      final boardSeed1 = generator.generate(
        cols: cols,
        rows: rows,
        arrowCount: arrowCount,
        maxPathLen: maxPathLen,
        seed: 1,
      );
      final boardSeed2 = generator.generate(
        cols: cols,
        rows: rows,
        arrowCount: arrowCount,
        maxPathLen: maxPathLen,
        seed: 2,
      );
      final jsonSeed1 = encoder.encode(levelId: levelId, board: boardSeed1);
      final jsonSeed2 = encoder.encode(levelId: levelId, board: boardSeed2);

      // Assert
      expect(jsonSeed1, isNot(equals(jsonSeed2)));
    });
  });
}
