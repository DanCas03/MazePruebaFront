import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/generate_board_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

import 'generate_board_use_case_test.mocks.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';

@GenerateMocks([ILevelGenerator, ILoggerService])
void main() {
  late MockILevelGenerator generator;
  late MockILoggerService logger;
  late GenerateBoardUseCase useCase;

  const stubBoard = ArrowBoard(arrows: [], space: RectSpace(6, 6));

  setUp(() {
    generator = MockILevelGenerator();
    logger = MockILoggerService();
    useCase = GenerateBoardUseCase(generator, logger);
    when(generator.generate(
      cols: anyNamed('cols'),
      rows: anyNamed('rows'),
      arrowCount: anyNamed('arrowCount'),
      maxPathLen: anyNamed('maxPathLen'),
      seed: anyNamed('seed'),
    )).thenReturn(stubBoard);
  });

  group('GenerateBoardUseCase', () {
    test('should_forward_derived_params_to_generator_when_seed_is_given', () {
      // Arrange
      final config = GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.easy, seed: 42);

      // Act
      useCase.execute(config);

      // Assert — 6x10 easy deriva 10 flechas (60·0.40/2.5) y maxPathLen 3; el
      // caso de uso traduce la config del jugador al contrato del puerto.
      verify(generator.generate(
        cols: 6,
        rows: 10,
        arrowCount: 10,
        maxPathLen: 3,
        seed: 42,
      )).called(1);
    });

    test('should_return_generator_board_seed_and_effective_config', () {
      // Arrange
      final config = GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.easy, seed: 42);

      // Act
      final result = useCase.execute(config);

      // Assert — el resultado empaqueta tablero + seed usada + config efectiva.
      expect(result.board, same(stubBoard));
      expect(result.seed, 42);
      expect(result.config, config);
    });

    test('should_generate_seed_via_injected_source_when_absent', () {
      // Arrange — fuente de seeds determinista inyectada.
      var calls = 0;
      useCase = GenerateBoardUseCase(generator, logger, seedSource: () {
        calls++;
        return 1234;
      });
      final config = GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.medium);

      // Act
      final result = useCase.execute(config);

      // Assert — la seed generada emerge en el resultado y viaja al generador
      // (6x10 medium: 60·0.55/4 = 8.25 → 8 flechas, maxPathLen 6).
      expect(calls, 1);
      expect(result.seed, 1234);
      expect(result.config, config.withSeed(1234));
      verify(generator.generate(
        cols: 6,
        rows: 10,
        arrowCount: 8,
        maxPathLen: 6,
        seed: 1234,
      )).called(1);
    });

    test('should_not_consume_seed_source_when_player_fixed_the_seed', () {
      // Arrange
      var calls = 0;
      useCase = GenerateBoardUseCase(generator, logger, seedSource: () {
        calls++;
        return 9;
      });

      // Act
      useCase.execute(GeneratorConfig.create(
          cols: 4, rows: 7, difficulty: Difficulty.hard, seed: 7));

      // Assert — la seed del jugador manda; la fuente aleatoria ni se toca.
      expect(calls, 0);
      verify(generator.generate(
        cols: 4,
        rows: 7,
        arrowCount: 4,
        maxPathLen: 9,
        seed: 7,
      )).called(1);
    });

    test('should_accept_graceful_degradation_without_failing', () {
      // Arrange — el stub devuelve 0 flechas frente a las pedidas: la
      // degradación con gracia del generador se acepta tal cual (issue #36).
      final config = GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.easy, seed: 1);

      // Act
      final result = useCase.execute(config);

      // Assert
      expect(result.board.arrows, isEmpty);
    });

    test('should_log_generation_with_use_case_context', () {
      // Act
      useCase.execute(GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.easy, seed: 42));

      // Assert — AOP: la seed queda en el log para reproducir el tablero.
      verify(logger.log(argThat(contains('seed=42')), 'GenerateBoardUseCase'))
          .called(1);
    });
  });

  group('GenerateBoardUseCase — determinismo (generador real)', () {
    test('should_produce_identical_boards_for_identical_seed_and_config', () {
      // Arrange — generador real: el determinismo es una propiedad del flujo
      // completo, no del mock.
      final real = GenerateBoardUseCase(GraphBoardGenerator(), logger);
      final config = GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.medium, seed: 20260713);

      // Act
      final first = real.execute(config);
      final second = real.execute(config);

      // Assert — ArrowBoard es Equatable: igualdad estructural profunda.
      expect(first.board, second.board);
      expect(first, second);
    });

    test('should_reproduce_board_from_surfaced_effective_config', () {
      // Arrange — primera generación sin seed (la pone la fuente inyectada).
      final real = GenerateBoardUseCase(GraphBoardGenerator(), logger,
          seedSource: () => 555);
      final first = real.execute(GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.hard));

      // Act — regenerar con la config efectiva que devolvió el resultado.
      final replay = real.execute(first.config);

      // Assert — la config efectiva basta para reproducir el tablero.
      expect(replay.board, first.board);
    });
  });

  group('GenerateBoardUseCase.executeAsync (front#66)', () {
    test('should_generate_inline_below_threshold_and_forward_seed', () async {
      // 6x10 (60 celdas) < isolateCellThreshold ⇒ camino síncrono en línea, así
      // que un generador mock (no enviable a un isolate) funciona igual.
      final config = GeneratorConfig.create(
          cols: 6, rows: 10, difficulty: Difficulty.easy, seed: 42);

      final result = await useCase.executeAsync(config);

      expect(result.board, same(stubBoard));
      expect(result.seed, 42);
      verify(generator.generate(
        cols: 6,
        rows: 10,
        arrowCount: 10,
        maxPathLen: 3,
        seed: 42,
      )).called(1);
    });

    test('should_offload_large_board_to_isolate_and_stay_deterministic',
        () async {
      // 19x34 (646 celdas, preset XL en banda front#101) >= isolateCellThreshold
      // ⇒ corre en un isolate vía `compute`. Con el generador REAL, el
      // resultado debe ser idéntico al camino síncrono para la misma seed
      // (determinismo a través del isolate).
      final real = GenerateBoardUseCase(GraphBoardGenerator(), logger);
      final config = GeneratorConfig.create(
          cols: 19, rows: 34, difficulty: Difficulty.medium, seed: 20260715);

      final async = await real.executeAsync(config);
      final sync = real.execute(config);

      expect(async.board, sync.board);
      expect(async.seed, 20260715);
      expect(async.config, config);
    });
  });
}
