import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generated_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_generator_config_exception.dart';

void main() {
  const board = ArrowBoard(arrows: [], cols: 4, rows: 4);

  GeneratorConfig config({int? seed}) => GeneratorConfig.create(
        cols: 4,
        rows: 4,
        difficulty: Difficulty.easy,
        seed: seed,
      );

  group('GeneratedBoard', () {
    test('should_surface_seed_from_effective_config', () {
      // Act
      final result = GeneratedBoard(board: board, config: config(seed: 99));

      // Assert — la seed usada siempre es visible en el resultado.
      expect(result.seed, 99);
    });

    test('should_reject_config_without_seed', () {
      // Assert — un tablero generado sin seed efectiva no es reproducible:
      // invariante defendida en el constructor.
      expect(
        () => GeneratedBoard(board: board, config: config()),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });

    test('should_equate_by_value', () {
      expect(
        GeneratedBoard(board: board, config: config(seed: 1)),
        GeneratedBoard(board: board, config: config(seed: 1)),
      );
      expect(
        GeneratedBoard(board: board, config: config(seed: 1)),
        isNot(GeneratedBoard(board: board, config: config(seed: 2))),
      );
    });
  });
}
