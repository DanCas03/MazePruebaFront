import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/state/generated_game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/generate_board_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/domain/game_core/services/i_ticker.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

Arrow _arrow(String id, int col) => straightArrow(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: 2,
    );

/// Tablero 4x4 con una flecha: al quitarla queda limpio → victoria.
ArrowBoard _oneArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0)], space: RectSpace(4, 4));

/// Tablero 4x4 con dos flechas rectas en la misma fila: la primera está
/// bloqueada por la segunda → cada toque es un choque (no se despeja).
ArrowBoard _twoArrowBoard() => ArrowBoard(
    arrows: [_arrow('arrow-0', 0), _arrow('arrow-2', 2)], space: RectSpace(4, 4));

/// Generador falso: registra las semillas con las que se le llama y devuelve el
/// tablero que dicte [boardFor] (o uno de una flecha por defecto).
class _FakeGenerator implements ILevelGenerator {
  final List<int?> seenSeeds = [];
  ArrowBoard Function()? boardFor;

  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    seenSeeds.add(seed);
    return boardFor?.call() ?? _oneArrowBoard();
  }
}

/// Logger inerte: el flujo generado no debe depender de efectos del logger.
class _NoopLogger implements ILoggerService {
  @override
  void log(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
  @override
  void warn(String message, String context) {}
}

/// Reloj falso controlado a mano (mismo patrón que game_controller_test).
class _FakeTicker implements ITicker {
  final _countdown = StreamController<int>.broadcast();
  int? requestedSeconds;

  @override
  Stream<int> countdown({required int seconds}) {
    requestedSeconds = seconds;
    return _countdown.stream;
  }

  @override
  Stream<int> elapsed() => const Stream.empty();

  void emit(int remaining) => _countdown.add(remaining);
}

GeneratorConfig _config({
  Difficulty difficulty = Difficulty.easy,
  bool timed = false,
  int? seed,
}) =>
    GeneratorConfig.create(
      cols: 4,
      rows: 4,
      difficulty: difficulty,
      timed: timed,
      seed: seed,
    );

ProviderContainer _container(
  _FakeGenerator generator, {
  ITicker ticker = const NullTicker(),
  int seedValue = 777,
}) {
  final useCase = GenerateBoardUseCase(
    generator,
    _NoopLogger(),
    seedSource: () => seedValue,
  );
  final c = ProviderContainer(overrides: [
    generatedGameControllerProvider.overrideWith(
      () => GeneratedGameController(
          useCase, RemoveArrowUseCase(), CommandInvoker(), ticker),
    ),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('GeneratedGameController · montaje', () {
    test('startNew emite GamePlaying con el tablero generado y 0 movimientos',
        () async {
      // Arrange
      final gen = _FakeGenerator()..boardFor = _twoArrowBoard;
      final c = _container(gen);
      // Fuerza la primera resolución del AsyncNotifier.
      await c.read(generatedGameControllerProvider.future);

      // Act
      await c.read(generatedGameControllerProvider.notifier).startNew(_config());

      // Assert
      final state = c.read(generatedGameControllerProvider).valueOrNull;
      expect(state, isA<GamePlaying>());
      expect((state as GamePlaying).moves.value, 0);
      expect(state.canUndo, isFalse);
    });

    test('sin semilla el caso de uso completa la seed y queda expuesta',
        () async {
      final gen = _FakeGenerator();
      final c = _container(gen, seedValue: 4242);
      final notifier = c.read(generatedGameControllerProvider.notifier);

      await notifier.startNew(_config()); // seed: null → la fija el SeedSource

      expect(notifier.currentSeed, 4242);
      expect(gen.seenSeeds.single, 4242);
    });

    test('no cronometrado: remainingSeconds null y no pide cuenta atrás',
        () async {
      final gen = _FakeGenerator();
      final ticker = _FakeTicker();
      final c = _container(gen, ticker: ticker);

      await c.read(generatedGameControllerProvider.notifier)
          .startNew(_config(timed: false));

      final state = c.read(generatedGameControllerProvider).valueOrNull;
      expect((state as GamePlaying).remainingSeconds, isNull);
      expect(ticker.requestedSeconds, isNull);
    });

    test('cronometrado: remainingSeconds = timeLimit derivado del preset',
        () async {
      final gen = _FakeGenerator();
      final ticker = _FakeTicker();
      final c = _container(gen, ticker: ticker);
      final config = _config(timed: true);

      await c.read(generatedGameControllerProvider.notifier).startNew(config);

      final state = c.read(generatedGameControllerProvider).valueOrNull;
      expect((state as GamePlaying).remainingSeconds, config.timeLimitSec);
      expect(ticker.requestedSeconds, config.timeLimitSec);
    });
  });

  group('GeneratedGameController · fin de partida', () {
    test('despejar el tablero emite GeneratedCleared, NUNCA GameWon', () async {
      // Cortafuegos: la victoria del flujo generado no puntúa. El estado
      // terminal no transporta Score/Stars/LevelId (nada persistible).
      final gen = _FakeGenerator()..boardFor = _oneArrowBoard;
      final c = _container(gen);
      final notifier = c.read(generatedGameControllerProvider.notifier);
      await notifier.startNew(_config());

      await notifier.tapArrow(const ArrowId('arrow-0'));

      final state = c.read(generatedGameControllerProvider).valueOrNull;
      expect(state, isA<GeneratedCleared>());
      expect(state, isNot(isA<GameWon>()));
      expect((state as GeneratedCleared).moves.value, 1);
    });

    test('al 5º choque emite GameLost (derrota por strikes)', () async {
      final gen = _FakeGenerator()..boardFor = _twoArrowBoard;
      final c = _container(gen);
      final notifier = c.read(generatedGameControllerProvider.notifier);
      await notifier.startNew(_config());

      // arrow-0 está bloqueada por arrow-2: cada toque es un choque.
      for (var i = 0; i < 4; i++) {
        await notifier.tapArrow(const ArrowId('arrow-0'));
        expect(c.read(generatedGameControllerProvider).valueOrNull,
            isA<GamePlaying>());
      }
      await notifier.tapArrow(const ArrowId('arrow-0'));

      final state = c.read(generatedGameControllerProvider).valueOrNull;
      expect(state, isA<GameLost>());
      expect((state as GameLost).strikes.value, 5);
    });

    test('agotar la cuenta atrás cronometrada emite GameLost', () async {
      final gen = _FakeGenerator()..boardFor = _twoArrowBoard;
      final ticker = _FakeTicker();
      final c = _container(gen, ticker: ticker);
      await c.read(generatedGameControllerProvider.notifier)
          .startNew(_config(timed: true));

      ticker.emit(0); // el reloj llega a cero
      await pumpEventQueue();

      expect(c.read(generatedGameControllerProvider).valueOrNull,
          isA<GameLost>());
    });
  });

  group('GeneratedGameController · acciones post-partida', () {
    test('anotherBoard regenera con NUEVA semilla y misma intención', () async {
      // seedSource incremental para distinguir "otro tablero".
      final gen = _FakeGenerator();
      var next = 100;
      final useCase = GenerateBoardUseCase(gen, _NoopLogger(),
          seedSource: () => next++);
      final c = ProviderContainer(overrides: [
        generatedGameControllerProvider.overrideWith(
          () => GeneratedGameController(
              useCase, RemoveArrowUseCase(), CommandInvoker()),
        ),
      ]);
      addTearDown(c.dispose);
      final notifier = c.read(generatedGameControllerProvider.notifier);

      await notifier.startNew(_config(difficulty: Difficulty.hard)); // seed 100
      final firstSeed = notifier.currentSeed;
      await notifier.anotherBoard(); // seed 101, misma config

      expect(firstSeed, 100);
      expect(notifier.currentSeed, 101);
      expect(notifier.currentConfig!.difficulty, Difficulty.hard);
      expect(gen.seenSeeds, [100, 101]);
    });

    test('repeat regenera con la MISMA semilla (tablero idéntico)', () async {
      final gen = _FakeGenerator();
      final c = _container(gen, seedValue: 555);
      final notifier = c.read(generatedGameControllerProvider.notifier);

      await notifier.startNew(_config()); // seed 555
      await notifier.repeat(); // vuelve a generar con seed 555

      expect(notifier.currentSeed, 555);
      expect(gen.seenSeeds, [555, 555]);
    });
  });
}
