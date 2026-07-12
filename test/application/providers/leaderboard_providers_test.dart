import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/providers/leaderboard_providers.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/submit_score_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';

import 'leaderboard_providers_test.mocks.dart';

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

/// Stub del puerto remoto (front#8): `getLevel` responde un [Level] con el
/// [board] dado; el levelId del run lo fija loadLevel, no el id del stub.
void _stubLevel(MockILevelRepository repo, ArrowBoard board) =>
    when(repo.getLevel(any)).thenAnswer(
        (_) async => Right(Level(id: LevelId('1'), board: board)));

/// Espía (Test Double) del puerto del leaderboard: registra cada score
/// enviado en vez de golpear la red, para poder aserir la forma exacta del
/// mapeo GameWon → ScoreEntry hecho por el Observer.
class _SpyLeaderboardRepository implements ILeaderboardRepository {
  final List<ScoreEntry> submitted = [];

  @override
  Future<void> submitScore(ScoreEntry entry) async => submitted.add(entry);

  // No usado en estas pruebas (envío): el puerto es cohesivo escritura+lectura.
  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    LevelId levelId, {
    int? limit,
  }) async =>
      const [];
}

/// Logger no-op: mantiene la salida de los tests limpia (el Observer/use case
/// solo loggean, no es parte del comportamiento bajo prueba aquí).
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
  _SpyLeaderboardRepository spyRepo,
) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(repo, uc, CommandInvoker())),
    submitScoreUseCaseProvider
        .overrideWithValue(SubmitScoreUseCase(spyRepo, _NoopLogger())),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
      'scoreSubmissionObserverProvider envía un ScoreEntry con los campos del run al ganar',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final spyRepo = _SpyLeaderboardRepository();
    final c = _container(repo, uc, spyRepo); // NullTicker ⇒ elapsed 0
    // Activa el Observer: su `ref.listen` debe registrarse ANTES de ganar.
    c.read(scoreSubmissionObserverProvider);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act
    await notifier.tapArrow(const ArrowId('arrow-0'));
    // El envío es fire-and-forget (unawaited); dejamos fluir el microtask.
    await Future<void>.delayed(Duration.zero);

    // Assert
    expect(spyRepo.submitted.length, 1);
    final entry = spyRepo.submitted.single;
    expect(entry.levelId, LevelId('7'));
    expect(entry.moves.value, 1);
    expect(entry.timeSeconds, 0);
    expect(entry.stars.value, 3);
    expect(entry.score.value, Score.base);
  });

  test('mapea el levelId correcto para un nivel distinto del default', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final spyRepo = _SpyLeaderboardRepository();
    final c = _container(repo, uc, spyRepo);
    c.read(scoreSubmissionObserverProvider);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('3'));

    // Act
    await notifier.tapArrow(const ArrowId('arrow-0'));
    await Future<void>.delayed(Duration.zero);

    // Assert — guarda contra un levelId hardcodeado o perdido en el mapeo.
    expect(spyRepo.submitted.length, 1);
    expect(spyRepo.submitted.single.levelId, LevelId('3'));
  });
}
