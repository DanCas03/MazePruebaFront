import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/audio/silent_audio_service.dart';
import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/providers/leaderboard_providers.dart';
import 'package:flutter_arrow_maze/application/providers/progress_providers.dart';
import 'package:flutter_arrow_maze/application/use_cases/record_level_completion_use_case.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/submit_score_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/logger_service_adapter.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/failures/solution_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_solution_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/domain/game_core/services/i_ticker.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/value_objects/canonical_result.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../../support/arrow_fixtures.dart';

// ── Dobles de test hechos a mano ─────────────────────────────────────────────

class _FakeLevelRepo implements ILevelRepository {
  final ArrowBoard board;
  _FakeLevelRepo(this.board);

  @override
  Future<Either<LevelFailure, Level>> getLevel(LevelId id) async =>
      Right(Level(id: id, board: board));

  @override
  Future<Either<LevelFailure, List<CatalogEntry>>> listCatalog() async =>
      Right([CatalogEntry(id: LevelId('1'), section: LevelSection.campaign)]);
}

class _FakeSolutionRepo implements ISolutionRepository {
  Either<SolutionFailure, List<ArrowId>>? response;
  Completer<Either<SolutionFailure, List<ArrowId>>>? deferred;
  int calls = 0;

  _FakeSolutionRepo({this.response, this.deferred});

  @override
  Future<Either<SolutionFailure, List<ArrowId>>> getSolution(LevelId id) {
    calls++;
    if (deferred != null) return deferred!.future;
    return Future.value(response);
  }
}

class _NoopLeaderboardRepository implements ILeaderboardRepository {
  @override
  Future<GlobalLeaderboard> getGlobalLeaderboard() async =>
      GlobalLeaderboard(top: const [], me: null);

  @override
  Future<CanonicalResult> submitScore(ScoreEntry entry) async =>
      CanonicalResult(score: Score(0), stars: const Stars.one());
  @override
  Future<List<LeaderboardEntry>> getLeaderboard(LevelId levelId, {int? limit}) async =>
      const [];
}

/// Repo de progreso no-op: el GameScreen activa el Observer de progreso
/// (front#58) al montar; los tests de hint no ejercen Hive.
class _NoopProgressRepository implements ILevelProgressRepository {
  @override
  Future<void> upsertAll(List<LevelProgress> progress) async {}
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

ArrowBoard _twoArrowBoard() => ArrowBoard(
      space: RectSpace(4, 4),
      arrows: [
        straightArrow(
          id: const ArrowId('a0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        straightArrow(
          id: const ArrowId('a2'),
          tail: Position(row: 0, col: 2),
          direction: Direction.right,
          length: 2,
        ),
      ],
    );

Widget _host(
  ProviderContainer container,
  LevelId levelId,
) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(levelId: levelId),
      ),
    );

ProviderContainer _container(_FakeLevelRepo levelRepo, _FakeSolutionRepo solutionRepo) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider.overrideWith(
      () => GameController(
        levelRepo,
        RemoveArrowUseCase(),
        CommandInvoker(),
        const NullTicker(),
        solutionRepo,
        (_) => Duration.zero,
      ),
    ),
    submitScoreUseCaseProvider.overrideWithValue(
      SubmitScoreUseCase(_NoopLeaderboardRepository(), LoggerServiceAdapter()),
    ),
    recordLevelCompletionUseCaseProvider.overrideWithValue(
      RecordLevelCompletionUseCase(
          _NoopProgressRepository(), LoggerServiceAdapter()),
    ),
    audioServiceProvider.overrideWithValue(const SilentAudioService()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets(
      'renders the auto-solve button even on a level below the old #32 threshold (#102)',
      (tester) async {
    // Arrange — el GameScreen auto-carga vía su callback post-frame. Nivel 1:
    // por debajo del viejo umbral (>= 7), ahora elegible para todo campaña.
    final container = _container(
      _FakeLevelRepo(_twoArrowBoard()),
      _FakeSolutionRepo(response: Right([const ArrowId('a0'), const ArrowId('a2')])),
    );
    // Act
    await tester.pumpWidget(_host(container, LevelId('1')));
    await tester.pumpAndSettle();
    // Assert — el control del auto-solver está presente en el AppBar,
    // explícitamente presentado (vara mágica, no la bombilla vieja de "pista").
    expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
  });

  testWidgets(
      'tapping the button opens a confirmation dialog warning progress will be lost',
      (tester) async {
    final container = _container(
      _FakeLevelRepo(_twoArrowBoard()),
      _FakeSolutionRepo(response: Right([const ArrowId('a0'), const ArrowId('a2')])),
    );
    await tester.pumpWidget(_host(container, LevelId('7')));
    await tester.pumpAndSettle();

    // Act — pulsa el control del auto-solver.
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();

    // Assert — el diálogo de confirmación aparece con sus dos acciones; el
    // auto-solver todavía NO corrió (ninguna petición de solución en vuelo).
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Auto-solve this level?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Auto-solve'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('canceling the confirmation dialog leaves the game untouched',
      (tester) async {
    final solutionRepo =
        _FakeSolutionRepo(response: Right([const ArrowId('a0'), const ArrowId('a2')]));
    final container = _container(_FakeLevelRepo(_twoArrowBoard()), solutionRepo);
    await tester.pumpWidget(_host(container, LevelId('7')));
    await tester.pumpAndSettle();

    // Act — abre el diálogo y pulsa Cancel.
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Assert — el diálogo se cerró, NUNCA se pidió la Solución, y la partida
    // sigue exactamente igual (sin carga ni reproducción, tablero intacto).
    expect(find.byType(AlertDialog), findsNothing);
    expect(solutionRepo.calls, 0);
    final s = container.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.hintLoading, isFalse);
    expect(s.hintPlaying, isFalse);
    expect(s.board.arrows.length, 2);
    expect(find.byIcon(Icons.auto_fix_high), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'confirming the dialog transforms the icon into a spinner while the solution loads',
      (tester) async {
    // Arrange — respuesta diferida: la petición queda en tránsito.
    final deferred = Completer<Either<SolutionFailure, List<ArrowId>>>();
    final container = _container(
      _FakeLevelRepo(_twoArrowBoard()),
      _FakeSolutionRepo(deferred: deferred),
    );
    await tester.pumpWidget(_host(container, LevelId('7')));
    await tester.pumpAndSettle();

    // Act — abre el diálogo y confirma.
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto-solve'));
    await tester.pump(); // cierra el diálogo y dispara playHint()
    await tester.pump();

    // Assert — el icono se transforma en un spinner (anti doble-clic) y ya no
    // hay icono pulsable del auto-solver.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high), findsNothing);

    // Cierra la petición para no dejar el future colgado.
    deferred.complete(const Left(SolutionUnavailable()));
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error snackbar when the auto-solve fetch fails',
      (tester) async {
    final container = _container(
      _FakeLevelRepo(_twoArrowBoard()),
      _FakeSolutionRepo(response: const Left(SolutionUnavailable())),
    );
    await tester.pumpWidget(_host(container, LevelId('7')));
    await tester.pumpAndSettle();

    // Act — confirma el diálogo; el fetch falla y debe emerger el snackbar.
    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto-solve'));
    await tester.pump(); // cierra el diálogo y dispara el fetch
    await tester.pump(); // deja emerger el snackbar

    // Assert
    expect(find.text('Couldn\'t auto-solve this level. Try again.'), findsOneWidget);
  });
}
