import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_generator_config_exception.dart';

void main() {
  GeneratorConfig valid({
    int cols = 6,
    int rows = 6,
    Difficulty difficulty = Difficulty.medium,
    bool timed = false,
    int? seed,
  }) =>
      GeneratorConfig.create(
        cols: cols,
        rows: rows,
        difficulty: difficulty,
        timed: timed,
        seed: seed,
      );

  group('GeneratorConfig.create — validación de dimensiones', () {
    test('should_accept_dimensions_at_both_bounds', () {
      // Act
      final min = valid(
        cols: GeneratorConfig.minDimension,
        rows: GeneratorConfig.minDimension,
      );
      final max = valid(
        cols: GeneratorConfig.maxDimension,
        rows: GeneratorConfig.maxDimension,
      );

      // Assert — los extremos del rango (4 y 50) son válidos, inclusive.
      // El techo subió a 50 en front#66 (viewport de zoom/pan): el preset XL.
      expect(min.cols, 4);
      expect(min.rows, 4);
      expect(max.cols, 50);
      expect(max.rows, 50);
    });

    test('should_reject_cols_below_range_with_domain_failure', () {
      expect(
        () => valid(cols: GeneratorConfig.minDimension - 1),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });

    test('should_reject_cols_above_range_with_domain_failure', () {
      expect(
        () => valid(cols: GeneratorConfig.maxDimension + 1),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });

    test('should_reject_rows_below_range_with_domain_failure', () {
      expect(
        () => valid(rows: GeneratorConfig.minDimension - 1),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });

    test('should_reject_rows_above_range_with_domain_failure', () {
      expect(
        () => valid(rows: GeneratorConfig.maxDimension + 1),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });

    test('should_name_offending_dimension_and_range_in_message', () {
      // Assert — el mensaje es semántico: dice QUÉ dimensión falló, el rango
      // permitido y el valor recibido (diagnóstico sin depurador).
      expect(
        () => valid(rows: 51),
        throwsA(
          isA<InvalidGeneratorConfigException>().having(
            (e) => e.message,
            'message',
            allOf(contains('rows'), contains('4'), contains('50'),
                contains('51')),
          ),
        ),
      );
    });
  });

  group('derivación por preset de dificultad', () {
    test('should_derive_arrow_count_from_density_and_avg_path_len', () {
      // Assert — celdas·fillRatio / largo medio ((2+maxPathLen)/2), redondeado:
      // 6x6 easy: 36·0.40/2.5 = 5.76 → 6 | 8x8 medium: 64·0.55/4 = 8.8 → 9 |
      // 10x10 hard: 100·0.70/5.5 = 12.7 → 13.
      expect(valid(cols: 6, rows: 6, difficulty: Difficulty.easy).arrowCount, 6);
      expect(
          valid(cols: 8, rows: 8, difficulty: Difficulty.medium).arrowCount, 9);
      expect(
          valid(cols: 10, rows: 10, difficulty: Difficulty.hard).arrowCount, 13);
    });

    test('should_clamp_arrow_count_to_playable_minimum_on_small_boards', () {
      // Assert — 4x4 hard: 16·0.70/5.5 = 2.04 → 2, por debajo del piso
      // jugable → se eleva a minArrowCount.
      expect(
        valid(cols: 4, rows: 4, difficulty: Difficulty.hard).arrowCount,
        GeneratorConfig.minArrowCount,
      );
    });

    test('should_expose_preset_max_path_len', () {
      expect(valid(difficulty: Difficulty.easy).maxPathLen, 3);
      expect(valid(difficulty: Difficulty.medium).maxPathLen, 6);
      expect(valid(difficulty: Difficulty.hard).maxPathLen, 9);
    });
  });

  group('derivación del timer', () {
    test('should_exclude_time_limit_when_not_timed', () {
      expect(valid(timed: false).timeLimitSec, isNull);
    });

    test('should_derive_time_limit_from_difficulty_and_board_size', () {
      // Assert — celdas·secondsPerCell: 6x6 easy 108 s | 8x8 medium 128 s |
      // 10x10 hard 150 s.
      expect(
        valid(cols: 6, rows: 6, difficulty: Difficulty.easy, timed: true)
            .timeLimitSec,
        108,
      );
      expect(
        valid(cols: 8, rows: 8, difficulty: Difficulty.medium, timed: true)
            .timeLimitSec,
        128,
      );
      expect(
        valid(cols: 10, rows: 10, difficulty: Difficulty.hard, timed: true)
            .timeLimitSec,
        150,
      );
    });

    test('should_clamp_time_limit_to_floor_and_ceiling', () {
      // Assert — 4x4 hard: 24 s → piso 30 | 10x10 easy: 300 s = techo exacto.
      expect(
        valid(cols: 4, rows: 4, difficulty: Difficulty.hard, timed: true)
            .timeLimitSec,
        GeneratorConfig.minTimeLimitSec,
      );
      expect(
        valid(cols: 10, rows: 10, difficulty: Difficulty.easy, timed: true)
            .timeLimitSec,
        GeneratorConfig.maxTimeLimitSec,
      );
    });
  });

  group('seed y semántica de valor', () {
    test('should_keep_optional_seed_absent_by_default', () {
      expect(valid().seed, isNull);
    });

    test('should_copy_config_with_seed_preserving_the_rest', () {
      // Arrange
      final config = valid(cols: 5, rows: 9, difficulty: Difficulty.hard, timed: true);

      // Act
      final effective = config.withSeed(77);

      // Assert
      expect(effective.seed, 77);
      expect(effective.cols, 5);
      expect(effective.rows, 9);
      expect(effective.difficulty, Difficulty.hard);
      expect(effective.timed, isTrue);
    });

    test('should_equate_by_value', () {
      expect(valid(seed: 1), valid(seed: 1));
      expect(valid(seed: 1), isNot(valid(seed: 2)));
    });
  });
}
