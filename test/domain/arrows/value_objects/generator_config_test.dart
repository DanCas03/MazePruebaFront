import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_generator_config_exception.dart';

void main() {
  // Default shape is 6x10 (0.60): inside AspectBand ([0.53, 0.68], front#101),
  // so any test that doesn't care about the exact shape can rely on it.
  GeneratorConfig valid({
    int cols = 6,
    int rows = 10,
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
      // Act — el rango jugable [4,50] ahora convive con AspectBand: no toda
      // combinación cuadrada cols=rows sigue siendo válida (ver el grupo de
      // validación de aspecto más abajo). cols no puede llegar a 50 sin que
      // rows exceda también 50 (la banda exigiría rows>=74), así que cada
      // extremo se prueba por separado con una forma en banda.
      final atColsFloor = valid(cols: GeneratorConfig.minDimension, rows: 7); // 4/7=0.571
      final atRowsCeil = valid(cols: 30, rows: GeneratorConfig.maxDimension); // 30/50=0.6

      // Assert — los extremos del rango (4 y 50) son alcanzables, inclusive.
      // El techo subió a 50 en front#66 (viewport de zoom/pan): el preset XL.
      expect(atColsFloor.cols, GeneratorConfig.minDimension);
      expect(atRowsCeil.rows, GeneratorConfig.maxDimension);
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

  group('validación de aspecto (AspectBand)', () {
    test('acepta una config dentro de la banda', () {
      expect(
          () => GeneratorConfig.create(
              cols: 9, rows: 16, difficulty: Difficulty.medium),
          returnsNormally); // 0.5625
      expect(
          () => GeneratorConfig.create(
              cols: 6, rows: 10, difficulty: Difficulty.medium),
          returnsNormally); // 0.60
    });
    test('rechaza un tablero cuadrado (fuera de banda)', () {
      expect(
        () => GeneratorConfig.create(
            cols: 25, rows: 25, difficulty: Difficulty.medium),
        throwsA(isA<InvalidGeneratorConfigException>()
            .having((e) => e.message, 'message', contains('aspect'))),
      );
    });
    test('rechaza un portrait demasiado ancho (0.75 > 0.68)', () {
      expect(
          () => GeneratorConfig.create(
              cols: 6, rows: 8, difficulty: Difficulty.medium),
          throwsA(isA<InvalidGeneratorConfigException>()));
    });
    test('rechaza un portrait demasiado estrecho (0.50 < 0.53)', () {
      expect(
          () => GeneratorConfig.create(
              cols: 10, rows: 20, difficulty: Difficulty.medium),
          throwsA(isA<InvalidGeneratorConfigException>()));
    });
  });

  group('derivación por preset de dificultad', () {
    test('should_derive_arrow_count_from_density_and_avg_path_len', () {
      // Assert — celdas·fillRatio / largo medio ((2+maxPathLen)/2), redondeado,
      // sobre formas en banda (front#101):
      // easy 6×10 (60): 60*0.40/2.5 = 9.6 -> 10
      expect(
          GeneratorConfig.create(cols: 6, rows: 10, difficulty: Difficulty.easy)
              .arrowCount,
          10);
      // medium 9×16 (144): 144*0.55/4 = 19.8 -> 20
      expect(
          GeneratorConfig.create(
                  cols: 9, rows: 16, difficulty: Difficulty.medium)
              .arrowCount,
          20);
      // hard 6×10 (60): 60*0.70/5.5 = 7.63 -> 8
      expect(
          GeneratorConfig.create(cols: 6, rows: 10, difficulty: Difficulty.hard)
              .arrowCount,
          8);
    });

    test('should_clamp_arrow_count_to_playable_minimum_on_small_boards', () {
      // Assert — hard 4×7 (28): 28*0.70/5.5 = 3.56 -> 4 (clamped to
      // minArrowCount; el board más pequeño en banda con cols=minDimension).
      expect(
        GeneratorConfig.create(cols: 4, rows: 7, difficulty: Difficulty.hard)
            .arrowCount,
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
      // Assert — celdas·secondsPerCell sobre formas en banda (front#101):
      // easy 6×10=60c ×3.0=180 | medium 9×16=144c ×2.0=288 | hard 6×10=60c ×1.5=90.
      expect(
        GeneratorConfig.create(
                cols: 6, rows: 10, difficulty: Difficulty.easy, timed: true)
            .timeLimitSec,
        180,
      );
      expect(
        GeneratorConfig.create(
                cols: 9, rows: 16, difficulty: Difficulty.medium, timed: true)
            .timeLimitSec,
        288,
      );
      expect(
        GeneratorConfig.create(
                cols: 6, rows: 10, difficulty: Difficulty.hard, timed: true)
            .timeLimitSec,
        90,
      );
    });

    test('should_clamp_time_limit_to_floor_and_ceiling', () {
      // floor unreachable in-band: el board más chico en banda (cols en el
      // piso jugable, 4) ya supera el piso de 30s incluso en hard (24s con
      // 4×4 cuadrado, pero 4×4 ya no es válido — el mínimo en banda es 4×6/4×7
      // y da 36s/42s), así que no hay caso de piso observable sin salir de
      // AspectBand.
      // Assert — ceiling: medium 19×34 (646 celdas): 646*2.0 = 1292 -> clamp a 300.
      expect(
        GeneratorConfig.create(
                cols: 19, rows: 34, difficulty: Difficulty.medium, timed: true)
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
      final config =
          valid(cols: 5, rows: 9, difficulty: Difficulty.hard, timed: true);

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
