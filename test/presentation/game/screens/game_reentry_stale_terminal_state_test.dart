import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/audio/silent_audio_service.dart';
import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/providers/leaderboard_providers.dart';
import 'package:flutter_arrow_maze/application/providers/progress_providers.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/record_level_completion_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/submit_score_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/logger_service_adapter.dart';
import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/value_objects/canonical_result.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

import 'game_screen_test.mocks.dart';
import '../../../support/arrow_fixtures.dart';

/// Controller cuyo `loadLevel` es no-op y expone `emit` para guionizar estados:
/// simula que el provider (no autoDispose) retiene un GameWon del nivel anterior
/// y lo re-observa una pantalla montada para OTRO nivel.
class _ScriptableGameController extends GameController {
  _ScriptableGameController()
      : super(MockILevelRepository(), RemoveArrowUseCase(), CommandInvoker());
  @override
  Future<void> loadLevel(LevelId levelId) async {}
  void emit(GameState next) => state = AsyncValue.data(next);
}

class _TerminalNavObserver extends NavigatorObserver {
  final List<String?> entries = [];
  void _record(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == AppRouter.victory || name == AppRouter.defeat) entries.add(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _record(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _record(newRoute);
}

/// 4×4 con una única flecha de salida libre: taparla vacía el tablero → GameWon.
ArrowBoard _singleArrowBoard() => ArrowBoard(
      space: RectSpace(4, 4),
      arrows: [
        straightArrow(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.left,
          length: 1,
        ),
      ],
    );

MockILevelRepository _repoWithBoard(ArrowBoard board) {
  final repo = MockILevelRepository();
  when(repo.getLevel(any)).thenAnswer((_) async => Right<LevelFailure, Level>(
        Level(id: LevelId('level-01'), board: board, maxErrors: 5),
      ));
  return repo;
}

/// Leaderboard repo que CUENTA los envíos por nivel.
class _CountingLeaderboardRepository implements ILeaderboardRepository {
  final List<String> submitted = [];
  @override
  Future<CanonicalResult> submitScore(ScoreEntry entry) async {
    submitted.add(entry.levelId.value);
    // ADR 0006: el back devuelve el resultado canónico; aquí espejamos el
    // preview del entry (este test no ejercita la reconciliación de valores).
    return CanonicalResult(score: entry.score, stars: entry.stars);
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(LevelId levelId, {int? limit}) async =>
      const [];

  @override
  Future<GlobalLeaderboard> getGlobalLeaderboard() async =>
      GlobalLeaderboard(top: const []);
}

/// Progress repo que CUENTA las escrituras de completado por nivel.
class _CountingProgressRepository implements ILevelProgressRepository {
  final List<String> recorded = [];
  @override
  Future<void> upsertAll(List<LevelProgress> progress) async =>
      recorded.addAll(progress.map((p) => p.levelId.value));
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

void main() {
  test(
      'winning then loading another level must NOT re-submit the previous level '
      '(observers fire only on the transition INTO GameWon)', () async {
    // Arrange — controller real + repos que cuentan envíos/escrituras.
    final leaderboard = _CountingLeaderboardRepository();
    final progress = _CountingProgressRepository();
    final container = ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
            _repoWithBoard(_singleArrowBoard()), RemoveArrowUseCase(), CommandInvoker()),
      ),
      submitScoreUseCaseProvider.overrideWithValue(
        SubmitScoreUseCase(leaderboard, LoggerServiceAdapter()),
      ),
      recordLevelCompletionUseCaseProvider.overrideWithValue(
        RecordLevelCompletionUseCase(progress, LoggerServiceAdapter()),
      ),
    ]);
    addTearDown(container.dispose);

    // Activa los dos observers (como hace GameScreen con ref.watch).
    container.read(scoreSubmissionObserverProvider);
    container.read(levelCompletionObserverProvider);

    final notifier = container.read(gameControllerProvider.notifier);

    // Act — juega y GANA el nivel 1.
    await notifier.loadLevel(LevelId('level-01'));
    await notifier.tapArrow(const ArrowId('a1'));
    await container.pump(); // deja correr los fire-and-forget
    // Instantánea tras la victoria. El ENVÍO es exactamente uno; el REGISTRO
    // puede ser >1 por la reconciliación canónica de ADR 0006 (el observer de
    // progreso registra el preview y `_submitAndReconcile` re-registra el
    // canónico, idempotente best-of) — irrelevante para este invariante.
    final submittedAfterWin = List.of(leaderboard.submitted);
    final recordedAfterWin = List.of(progress.recorded);

    // ...y luego ENTRA a otro nivel (loadLevel de nuevo): el estado de carga
    // RETIENE el GameWon anterior, pero la guarda de borde impide re-disparar.
    await notifier.loadLevel(LevelId('level-02'));
    await container.pump();

    // Assert — cargar otro nivel NO re-envía ni re-registra el nivel ya ganado.
    expect(leaderboard.submitted, ['level-01']); // un solo envío; ninguno al recargar
    expect(leaderboard.submitted, submittedAfterWin);
    expect(progress.recorded, recordedAfterWin); // sin nuevos registros al recargar
    expect(progress.recorded, everyElement('level-01')); // nunca del nivel nuevo
  });

  testWidgets(
      'GameScreen for level-02 must NOT navigate to the victory of level-01 '
      '(per-level invariant)', (tester) async {
    // Arrange — controller guionizado; la pantalla es para level-02.
    final controller = _ScriptableGameController();
    final container = ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(() => controller),
      submitScoreUseCaseProvider.overrideWithValue(
        SubmitScoreUseCase(_CountingLeaderboardRepository(), LoggerServiceAdapter()),
      ),
      recordLevelCompletionUseCaseProvider.overrideWithValue(
        RecordLevelCompletionUseCase(_CountingProgressRepository(), LoggerServiceAdapter()),
      ),
      audioServiceProvider.overrideWithValue(const SilentAudioService()),
    ]);
    addTearDown(container.dispose);
    final observer = _TerminalNavObserver();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        onGenerateRoute: (settings) => switch (settings.name) {
          AppRouter.victory => MaterialPageRoute<void>(
              settings: settings, builder: (_) => const VictoryScreen()),
          _ => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => GameScreen(levelId: LevelId('level-02'))),
        },
      ),
    ));
    await tester.pumpAndSettle();

    // Act — el controller re-observa un GameWon REZAGADO del nivel ANTERIOR
    // (level-01) mientras la pantalla montada es la del level-02. El listener
    // dispara en el borde (prev=GameLoading), pero el nivel NO coincide.
    controller.emit(GameWon(
      moves: const MoveCount(1),
      score: Score(9000),
      stars: const Stars.three(),
      timeSeconds: 0,
      collisions: 0,
      levelId: LevelId('level-01'),
    ));
    await tester.pumpAndSettle();

    // Assert — NADA de navegar a la victoria de otro nivel.
    expect(observer.entries, isEmpty);
    expect(find.byType(VictoryScreen), findsNothing);
  });
}
