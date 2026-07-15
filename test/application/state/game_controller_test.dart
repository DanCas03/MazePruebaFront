import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/services/i_ticker.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';

import 'game_controller_test.mocks.dart';

@GenerateMocks([ILevelRepository, RemoveArrowUseCase])
Arrow _arrow(String id, int col) => Arrow.straight(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: 2,
    );

/// Tablero 4x4 con dos flechas (no se vacía al quitar una).
ArrowBoard _twoArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0), _arrow('arrow-2', 2)], cols: 4, rows: 4);

/// Tablero 4x4 con una sola flecha (al quitarla queda limpio → victoria).
ArrowBoard _oneArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0)], cols: 4, rows: 4);

ProviderContainer _container(MockILevelRepository repo, MockRemoveArrowUseCase uc) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(repo, uc, CommandInvoker())),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Contenedor con un reloj falso inyectado, para ejercer la cuenta atrás sin
/// depender del tiempo real (mock clock → sin fragilidad).
ProviderContainer _containerWithTicker(
    MockILevelRepository repo, MockRemoveArrowUseCase uc, ITicker ticker) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(repo, uc, CommandInvoker(), ticker)),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Reloj falso controlado a mano: `emit` empuja la cuenta atrás y `emitElapsed`
/// el cronómetro ascendente, sin esperar segundos reales.
class _FakeTicker implements ITicker {
  final _countdown = StreamController<int>.broadcast();
  final _elapsed = StreamController<int>.broadcast();
  int? requestedSeconds; // segundos con los que se pidió la cuenta atrás

  @override
  Stream<int> countdown({required int seconds}) {
    requestedSeconds = seconds;
    return _countdown.stream;
  }

  @override
  Stream<int> elapsed() => _elapsed.stream;

  void emit(int remaining) => _countdown.add(remaining);
  void emitElapsed(int seconds) => _elapsed.add(seconds);
}

/// Stub del puerto remoto (front#8): `getLevel` responde un [Level] con el
/// [board] dado; el límite de tiempo viene del propio Level, no de blueprints.
void _stubLevel(MockILevelRepository repo, ArrowBoard board,
        {int? timeLimitSec}) =>
    when(repo.getLevel(any)).thenAnswer((_) async =>
        Right(Level(id: LevelId('1'), board: board, timeLimitSec: timeLimitSec)));

void main() {
  test('loadLevel emite GamePlaying con el board remoto y 0 movimientos', () async {
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    final board = _twoArrowBoard();
    _stubLevel(repo, board);
    final c = _container(repo, uc);

    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GamePlaying>());
    expect((state as GamePlaying).moves.value, 0);
    expect(state.board, board);
    expect(state.canUndo, isFalse);
  });

  test('loadLevel pide al repositorio exactamente el LevelId solicitado', () async {
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    final c = _container(repo, uc);

    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('3'));

    verify(repo.getLevel(LevelId('3'))).called(1);
  });

  test('tapArrow bloqueada hace shake: blockedArrow seteada y blockedNonce sube', () async {
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('blocked')));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));
    final s1 = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s1.blockedArrow, const ArrowId('arrow-0'));
    expect(s1.blockedNonce, 1);
    expect(s1.board.arrows.length, 2); // no cambió el tablero

    await notifier.tapArrow(const ArrowId('arrow-0'));
    final s2 = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s2.blockedNonce, 2); // re-dispara
  });

  test('tapArrow legal remueve la flecha, +1 movimiento, exitingArrow y canUndo', () async {
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.moves.value, 1);
    expect(s.exitingArrow?.id, const ArrowId('arrow-0'));
    expect(s.exitNonce, 1);
    expect(s.canUndo, isTrue);
  });

  test('tapArrow que limpia el tablero emite GameWon con score/stars/time/level',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final c = _container(repo, uc); // NullTicker ⇒ elapsed 0
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    // Act
    await notifier.tapArrow(const ArrowId('arrow-0'));
    // Assert
    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GameWon>());
    final won = state as GameWon;
    expect(won.moves.value, 1);
    expect(won.timeSeconds, 0); // sin cronómetro real
    expect(won.levelId, LevelId('1'));
    // óptimo = 1 flecha (Level.board.arrows.length), 0 choques, tiempo 0
    // ⇒ partida perfecta.
    expect(won.stars.value, 3);
    expect(won.score.value, Score.base);
  });

  test('GameWon lleva timeSeconds del cronómetro y penaliza el score', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final ticker = _FakeTicker();
    final c = _containerWithTicker(repo, uc, ticker);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    // Act — el cronómetro marca 30 s antes de ganar.
    ticker.emitElapsed(30);
    await Future<void>.delayed(Duration.zero); // deja fluir el evento del stream
    await notifier.tapArrow(const ArrowId('arrow-0'));
    // Assert
    final won = c.read(gameControllerProvider).valueOrNull as GameWon;
    expect(won.timeSeconds, 30);
    // óptimo 1, 0 choques, 30 s ⇒ score = base - 30*timePenaltyPerSecond.
    expect(won.score.value, Score.base - 30 * Score.timePenaltyPerSecond);
  });

  test('should_keep_playing_when_fourth_collision', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('blocked')));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act
    for (var i = 0; i < 4; i++) {
      await notifier.tapArrow(const ArrowId('arrow-0'));
    }

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GamePlaying>());
    expect((state as GamePlaying).strikes.value, 4);
  });

  test('should_lose_when_fifth_collision', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('blocked')));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act
    for (var i = 0; i < 5; i++) {
      await notifier.tapArrow(const ArrowId('arrow-0'));
    }

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GameLost>());
    expect((state as GameLost).strikes.value, 5);
    expect(state.strikes.isFatal, isTrue);
  });

  test('should_reset_strikes_when_level_reloaded', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('blocked')));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    for (var i = 0; i < 5; i++) {
      await notifier.tapArrow(const ArrowId('arrow-0'));
    }

    // Act
    await notifier.restartLevel();

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GamePlaying>());
    expect((state as GamePlaying).strikes.value, 0);
  });

  test('undoMove restaura el tablero y decrementa movimientos', () async {
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    await notifier.tapArrow(const ArrowId('arrow-0'));

    await notifier.undoMove();

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.board.arrows.length, 2); // flecha reinsertada
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
  });

  test('should_preserve_move_count_when_undo_after_victory', () async {
    // Arrange: dos taps legales vacían el tablero → GameWon con moves == 2.
    // El tablero vacío post-victoria se reconstruye con las dimensiones del
    // Level remoto cacheado (_currentLevelData), no de un blueprint.
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    await notifier.tapArrow(const ArrowId('arrow-0'));
    await notifier.tapArrow(const ArrowId('arrow-2'));
    expect(c.read(gameControllerProvider).valueOrNull, isA<GameWon>());

    // Act
    await notifier.undoMove();

    // Assert: BUG-1 — el contador retrocede a N-1, no se reinicia a 0.
    final s = c.read(gameControllerProvider).valueOrNull;
    expect(s, isA<GamePlaying>());
    expect((s as GamePlaying).moves.value, 1);
    expect(s.board.arrows.length, 1); // la última flecha fue reinsertada
  });

  test('restartLevel limpia el historial y remonta el nivel (canUndo false, 0 movimientos)', () async {
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('2'));
    await notifier.tapArrow(const ArrowId('arrow-0'));

    await notifier.restartLevel();

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
    expect(s.board.arrows.length, 2);
  });

  // ── Camino remoto (front#8) ─────────────────────────────────────────────────

  test('should_emit_error_when_getLevel_fails', () async {
    // Arrange — el repo falla (sin red y sin caché → LevelUnavailable).
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    when(repo.getLevel(any))
        .thenAnswer((_) async => Left(const LevelUnavailable()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);

    // Act
    await notifier.loadLevel(LevelId('1'));

    // Assert — AsyncError envolviendo el LevelFailure. Riverpod conserva el
    // último valor junto al error (copyWithPrevious del setter de state), así
    // que valueOrNull no es null: lo relevante es que el error esté expuesto
    // y que NO haya quedado una partida jugable (GamePlaying) filtrada.
    final state = c.read(gameControllerProvider);
    expect(state, isA<AsyncError<GameState>>());
    expect(state.error, isA<LevelUnavailable>());
    expect(state.valueOrNull, isNot(isA<GamePlaying>()));
  });

  test('should_not_refetch_when_restart', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act
    await notifier.restartLevel();

    // Assert — restart reutiliza el Level cacheado: getLevel solo se llamó
    // en el load inicial (un único fetch).
    verify(repo.getLevel(any)).called(1);
    final s = c.read(gameControllerProvider).valueOrNull;
    expect(s, isA<GamePlaying>());
    expect((s as GamePlaying).moves.value, 0);
  });

  test('should_recover_when_reload_after_previous_failure', () async {
    // Arrange — el primer intento falla (sin red y sin caché → LevelUnavailable).
    // Regresión post-review: una carga fallida deja el provider en AsyncError y,
    // en Riverpod 2.x, `future` queda completado con ese error. Sin el guard del
    // `await future`, el siguiente loadLevel rethrow-earía ANTES de refetch y la
    // campaña quedaría bloqueada toda la sesión (provider raíz, no autoDispose).
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    when(repo.getLevel(any))
        .thenAnswer((_) async => Left(const LevelUnavailable()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);

    // Act 1 — el primer load falla y deja el provider en AsyncError.
    await notifier.loadLevel(LevelId('1'));
    expect(c.read(gameControllerProvider), isA<AsyncError<GameState>>());

    // Act 2 — vuelve la red: el mismo nivel ahora resuelve y se reintenta.
    _stubLevel(repo, _twoArrowBoard());
    await notifier.loadLevel(LevelId('1'));

    // Assert — la campaña se recupera: el reintento hizo refetch y hay partida.
    final state = c.read(gameControllerProvider);
    expect(state, isA<AsyncData<GameState>>());
    expect(state.valueOrNull, isA<GamePlaying>());
  });

  test('should_not_restart_previous_level_when_load_fails', () async {
    // Arrange — un primer nivel carga bien (queda cacheado en _currentLevelData).
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard());
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    expect(c.read(gameControllerProvider).valueOrNull, isA<GamePlaying>());

    // Act — un segundo load falla; el error debe limpiar el nivel cacheado para
    // que un restart posterior no resucite silenciosamente el nivel anterior.
    when(repo.getLevel(any))
        .thenAnswer((_) async => Left(const LevelUnavailable()));
    await notifier.loadLevel(LevelId('2'));
    await notifier.restartLevel();

    // Assert — restart fue no-op (_currentLevelData se limpió en el fallo): el
    // provider sigue en AsyncError, sin una partida jugable del board viejo.
    // Pre-fix, restart remontaría el nivel 1 y el wrapper sería AsyncData.
    final state = c.read(gameControllerProvider);
    expect(state, isA<AsyncError<GameState>>());
    expect(state, isNot(isA<AsyncData<GameState>>()));
  });

  // ── Cuenta atrás inyectable (front#11) ──────────────────────────────────────
  // El límite ahora viene de Level.timeLimitSec (remoto), no de una curva local.

  test('should_start_countdown_when_level_has_time_limit', () async {
    // Arrange — nivel remoto cronometrado a 60 s.
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard(), timeLimitSec: 60);
    final ticker = _FakeTicker();
    final c = _containerWithTicker(repo, uc, ticker);
    final notifier = c.read(gameControllerProvider.notifier);

    // Act
    await notifier.loadLevel(LevelId('1'));

    // Assert — arranca el reloj con el límite del nivel y lo expone en el estado.
    expect(ticker.requestedSeconds, 60);
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.remainingSeconds, 60);
  });

  test('should_not_start_countdown_when_level_has_no_time_limit', () async {
    // Arrange — el Level remoto llega sin límite (timeLimitSec == null).
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard(), timeLimitSec: null);
    final ticker = _FakeTicker();
    final c = _containerWithTicker(repo, uc, ticker);
    final notifier = c.read(gameControllerProvider.notifier);

    // Act
    await notifier.loadLevel(LevelId('1'));

    // Assert — el reloj nunca se solicitó y el estado no lleva segundos.
    expect(ticker.requestedSeconds, isNull);
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.remainingSeconds, isNull);
  });

  test('should_update_remaining_seconds_when_ticker_emits', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard(), timeLimitSec: 60);
    final ticker = _FakeTicker();
    final c = _containerWithTicker(repo, uc, ticker);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act — el reloj falso avanza a 42 s restantes
    ticker.emit(42);
    await pumpEventQueue();

    // Assert
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.remainingSeconds, 42);
  });

  test('should_lose_when_time_runs_out', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _twoArrowBoard(), timeLimitSec: 60);
    final ticker = _FakeTicker();
    final c = _containerWithTicker(repo, uc, ticker);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act — el reloj llega a 0 (timeout)
    ticker.emit(0);
    await pumpEventQueue();

    // Assert — timeout ⇒ GameLost, conservando los movimientos hechos.
    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GameLost>());
    expect((state as GameLost).moves.value, 0);
  });

  test('should_ignore_timeout_when_level_already_won', () async {
    // Arrange — un solo tap legal vacía el tablero → GameWon antes del timeout.
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard(), timeLimitSec: 60);
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final ticker = _FakeTicker();
    final c = _containerWithTicker(repo, uc, ticker);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    await notifier.tapArrow(const ArrowId('arrow-0'));
    expect(c.read(gameControllerProvider).valueOrNull, isA<GameWon>());

    // Act — un tick tardío del reloj cancelado no debe robar la victoria.
    ticker.emit(0);
    await pumpEventQueue();

    // Assert
    expect(c.read(gameControllerProvider).valueOrNull, isA<GameWon>());
  });
}
