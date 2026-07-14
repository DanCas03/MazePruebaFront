import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/providers/progress_providers.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/record_level_completion_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';

import 'progress_providers_test.mocks.dart';

@GenerateMocks([ILevelRepository, RemoveArrowUseCase])
Arrow _arrow(String id, int col) => Arrow.straight(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: 2,
    );

/// Tablero 4x4 con una sola flecha (al quitarla queda limpio → victoria).
ArrowBoard _oneArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0)], cols: 4, rows: 4);

void _stubLevel(MockILevelRepository repo, ArrowBoard board) =>
    when(repo.getLevel(any)).thenAnswer(
        (_) async => Right(Level(id: LevelId('1'), board: board)));

/// Espía del puerto de progreso local: registra cada upsert en vez de tocar
/// Hive, para aserir que el Observer persiste el progreso al ganar.
class _SpyProgressRepository implements ILevelProgressRepository {
  final List<LevelProgress> upserts = [];

  @override
  Future<void> upsertAll(List<LevelProgress> progress) async =>
      upserts.addAll(progress);

  @override
  Future<List<LevelProgress>> getAll() async => const [];

  @override
  Future<MoveCount?> getProgress(LevelId levelId) async => null;

  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) async {}

  @override
  Future<void> markCompleted(LevelId levelId) async {}

  @override
  Future<bool> isCompleted(LevelId levelId) async => false;
}

/// Logger no-op: el Observer/use case solo loggean, no es lo que se prueba aquí.
class _NoopLogger implements ILoggerService {
  @override
  void log(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
  @override
  void warn(String message, String context) {}
}

ProviderContainer _container(
  MockILevelRepository repo,
  MockRemoveArrowUseCase uc,
  _SpyProgressRepository spy,
) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(repo, uc, CommandInvoker())),
    recordLevelCompletionUseCaseProvider.overrideWithValue(
      RecordLevelCompletionUseCase(spy, _NoopLogger()),
    ),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('persiste el progreso completado con las estadísticas del run al ganar',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final spy = _SpyProgressRepository();
    final c = _container(repo, uc, spy); // NullTicker ⇒ elapsed 0 ⇒ 3 estrellas
    // Activa el Observer ANTES de ganar (su `ref.listen` debe estar registrado).
    c.read(levelCompletionObserverProvider);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act
    await notifier.tapArrow(const ArrowId('arrow-0'));
    // La escritura es fire-and-forget (unawaited); dejamos correr el microtask.
    await Future<void>.delayed(Duration.zero);

    // Assert
    expect(spy.upserts.length, 1);
    final p = spy.upserts.single;
    expect(p.levelId, LevelId('7'));
    expect(p.completed, isTrue);
    expect(p.bestStars, 3);
    expect(p.bestScore, Score.base);
  });

  test('no persiste nada mientras la partida sigue en curso (no GameWon)',
      () async {
    // Arrange — tablero de DOS flechas: quitar una NO limpia el tablero.
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    final twoArrows = ArrowBoard(
      arrows: [_arrow('arrow-0', 0), _arrow('arrow-1', 2)],
      cols: 4,
      rows: 4,
    );
    _stubLevel(repo, twoArrows);
    // Quitar arrow-0 deja el tablero con arrow-1 (sigue GamePlaying).
    when(uc.execute(any, any)).thenReturn(
        Right(ArrowBoard(arrows: [_arrow('arrow-1', 2)], cols: 4, rows: 4)));
    final spy = _SpyProgressRepository();
    final c = _container(repo, uc, spy);
    c.read(levelCompletionObserverProvider);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act
    await notifier.tapArrow(const ArrowId('arrow-0'));
    await Future<void>.delayed(Duration.zero);

    // Assert — sin victoria, no hay escritura de progreso.
    expect(spy.upserts, isEmpty);
  });
}
