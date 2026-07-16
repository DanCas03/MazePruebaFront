import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

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
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/strike_count.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/submit_score_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/logger_service_adapter.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/value_objects/canonical_result.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/defeat_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';
import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';

import 'game_screen_test.mocks.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../../support/arrow_fixtures.dart';

// El GameController remoto (front#8) se construye con un ILevelRepository; el
// .mocks.dart co-localizado se genera con:
//   dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([ILevelRepository])

// ── Fixtures de tablero ──────────────────────────────────────────────────────

/// Tablero 4×4 con una única flecha de salida libre: al taparla el tablero queda
/// limpio y el juego transita a GameWon.
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

/// Tablero 4×4 cuya flecha objetivo ('a1') tiene la salida bloqueada por una
/// segunda flecha en su carril: cada tap sobre 'a1' es un choque, de modo que 5
/// taps llevan el juego a GameLost sin vaciar el tablero.
ArrowBoard _blockedArrowBoard() => ArrowBoard(
      space: RectSpace(4, 4),
      arrows: [
        // Sale hacia la derecha; su carril de salida (space.exitLane) incluye (0,3).
        straightArrow(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        // Ocupa (0,3) → bloquea la salida de 'a1'.
        straightArrow(
          id: const ArrowId('blk'),
          tail: Position(row: 0, col: 3),
          direction: Direction.right,
          length: 1,
        ),
      ],
    );

// ── Composición del repo remoto ──────────────────────────────────────────────

/// Repo de leaderboard no-op: los widget tests activan el Observer de envío de
/// score (front#16) pero no ejercen la red.
class _NoopLeaderboardRepository implements ILeaderboardRepository {
  @override
  Future<GlobalLeaderboard> getGlobalLeaderboard() async =>
      GlobalLeaderboard(top: const [], me: null);

  @override
  Future<CanonicalResult> submitScore(ScoreEntry entry) async =>
      CanonicalResult(score: Score(0), stars: const Stars.one());

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    LevelId levelId, {
    int? limit,
  }) async =>
      const [];
}

/// Repo de progreso no-op: los widget tests activan el Observer de progreso
/// (front#58) al ganar, pero no ejercen Hive.
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

/// Mock del puerto remoto (front#8) cuyo `getLevel` responde `Right(Level)` con
/// el [board] dado; el límite de tiempo viaja en el propio Level.
MockILevelRepository _repoWithBoard(ArrowBoard board,
    {int? timeLimitSec, int? maxErrors}) {
  final repo = MockILevelRepository();
  when(repo.getLevel(any)).thenAnswer((_) async => Right<LevelFailure, Level>(
        Level(
          id: LevelId('level-01'),
          board: board,
          timeLimitSec: timeLimitSec,
          maxErrors: maxErrors ?? 5,
        ),
      ));
  return repo;
}

/// Overrides comunes parametrizados por la fábrica del controller: Observer de
/// score/progreso no-op + audio silencioso (Null Object).
List<Override> _overridesWith(GameController Function() make) => [
      gameControllerProvider.overrideWith(make),
      submitScoreUseCaseProvider.overrideWithValue(
        SubmitScoreUseCase(_NoopLeaderboardRepository(), LoggerServiceAdapter()),
      ),
      recordLevelCompletionUseCaseProvider.overrideWithValue(
        RecordLevelCompletionUseCase(
            _NoopProgressRepository(), LoggerServiceAdapter()),
      ),
      audioServiceProvider.overrideWithValue(const SilentAudioService()),
    ];

/// Overrides comunes: GameController remoto sobre [repo]. El RemoveArrowUseCase
/// es real para que los taps ejerzan la lógica de salida/choque de dominio.
List<Override> _overrides(ILevelRepository repo) =>
    _overridesWith(() => GameController(repo, RemoveArrowUseCase(), CommandInvoker()));

/// front#98: controller que expone un canal para RE-EMITIR estados a mano,
/// simulando la re-emisión del async value estando ya en un estado terminal
/// (p. ej. el Observer de score que reconstruye el provider tras el POST).
/// `loadLevel` es un no-op para que el ÚNICO cambio de estado sea el guionizado.
class _ScriptableGameController extends GameController {
  _ScriptableGameController()
      : super(MockILevelRepository(), RemoveArrowUseCase(), CommandInvoker());

  @override
  Future<void> loadLevel(LevelId levelId) async {}

  void emit(GameState next) => state = AsyncValue.data(next);
}

/// Cuenta las entradas a rutas TERMINALES (victoria/derrota). `pushReplacement`
/// se refleja como `didReplace`, no como `didPush`: registramos ambas para no
/// perder ninguna navegación terminal.
class _TerminalNavObserver extends NavigatorObserver {
  final List<String?> entries = [];

  void _record(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == AppRouter.victory || name == AppRouter.defeat) {
      entries.add(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _record(newRoute);
}

/// Host con [observer] enganchado al Navigator, para contar navegaciones
/// terminales. Las rutas de victoria/derrota se resuelven a sus pantallas.
Widget _observedHost(ProviderContainer container, NavigatorObserver observer) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        onGenerateRoute: (settings) => switch (settings.name) {
          AppRouter.victory => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const VictoryScreen(),
            ),
          AppRouter.defeat => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const DefeatScreen(),
            ),
          _ => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => GameScreen(levelId: LevelId('level-01')),
            ),
        },
      ),
    );

ProviderContainer _container(ILevelRepository repo) =>
    ProviderContainer(overrides: _overrides(repo));

/// Host imperativo: los tests conducen el notifier a mano (`loadLevel`/`tapArrow`)
/// desde el [container]. El GameScreen se monta en la ruta por defecto.
Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) => switch (settings.name) {
          AppRouter.victory => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const VictoryScreen(),
            ),
          AppRouter.defeat => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const DefeatScreen(),
            ),
          _ => MaterialPageRoute<void>(
              builder: (_) => GameScreen(levelId: LevelId('1')),
            ),
        },
      ),
    );

/// Host declarativo para la rama de error: monta GameScreen como `home` y deja
/// que el callback post-frame dispare `loadLevel`. `onGenerateRoute` sabe
/// construir la ruta de selección de nivel (destino del botón "Back to Levels").
Widget _errorHost(ILevelRepository repo) => ProviderScope(
      overrides: _overrides(repo),
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) => switch (settings.name) {
          AppRouter.levelSelection => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Center(child: Text('level-selection-stub')),
              ),
            ),
          _ => MaterialPageRoute<void>(
              builder: (_) => GameScreen(levelId: LevelId('level-01')),
            ),
        },
        home: GameScreen(levelId: LevelId('level-01')),
      ),
    );

void main() {
  group('GameScreen', () {
    testWidgets('shows the moves counter while playing', (tester) async {
      // Arrange
      final container = _container(_repoWithBoard(_singleArrowBoard()));
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));

      // Act
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      await tester.pump();

      // Assert
      expect(find.text('Moves: 0'), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsOneWidget);
    });

    testWidgets('shows a descending error budget that drops on a collision',
        (tester) async {
      // Arrange — un nivel con presupuesto de 3 errores y salida bloqueada.
      final container =
          _container(_repoWithBoard(_blockedArrowBoard(), maxErrors: 3));
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      await tester.pump();

      // Assert — el contador arranca en el presupuesto del nivel (3).
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Act — un choque (tap a la flecha bloqueada) descuenta un error.
      await container
          .read(gameControllerProvider.notifier)
          .tapArrow(const ArrowId('a1'));
      await tester.pump();

      // Assert — el contador desciende a 2, sigue jugando.
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(DefeatScreen), findsNothing);
    });

    testWidgets('shows the countdown for a timed level', (tester) async {
      // Arrange — nivel cronometrado (90 s). Con el reloj por defecto (inerte)
      // el estado conserva el límite inicial, suficiente para verificar el render.
      final container =
          _container(_repoWithBoard(_singleArrowBoard(), timeLimitSec: 90));
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));

      // Act
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('6'));
      await tester.pump();

      // Assert — reloj visible con el formato m:ss (90 s → "1:30").
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);
    });

    testWidgets('hides the countdown for an untimed level', (tester) async {
      // Arrange — nivel sin límite de tiempo.
      final container = _container(_repoWithBoard(_singleArrowBoard()));
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));

      // Act
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('1'));
      await tester.pump();

      // Assert — sin reloj en la AppBar.
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
    });

    testWidgets('navigates to VictoryScreen when the board is cleared',
        (tester) async {
      // Arrange
      final container = _container(_repoWithBoard(_singleArrowBoard()));
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      // El id debe coincidir con el de la GameScreen montada (`_host` usa
      // LevelId('1')): en producción initState llama loadLevel(widget.levelId),
      // así que _currentLevel == widget.levelId. La navegación de victoria exige
      // esa coincidencia (invariante por nivel, front#98), por lo que el test
      // debe cargar el MISMO nivel que pinta la pantalla.
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('1'));
      await tester.pump();

      // Act — clear the only arrow, triggering GameWon -> navigation
      await container
          .read(gameControllerProvider.notifier)
          .tapArrow(const ArrowId('a1'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(VictoryScreen), findsOneWidget);
      expect(find.text('1 moves'), findsOneWidget);
    });

    testWidgets('navigates to DefeatScreen when the fifth collision is reached',
        (tester) async {
      // Arrange
      final container = _container(_repoWithBoard(_blockedArrowBoard()));
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      await tester.pump();

      // Act — tap the blocked arrow 5 times: GameLost -> navigation
      for (var i = 0; i < 5; i++) {
        await container
            .read(gameControllerProvider.notifier)
            .tapArrow(const ArrowId('a1'));
      }
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(DefeatScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(find.text('0 moves · 5 strikes'), findsOneWidget);
    });

    // BUG-2 regression: provider overridden + loadLevel called on mount
    testWidgets(
      'BUG-2 regression: navigating to /game via router renders board without manual loadLevel call',
      (tester) async {
        // Arrange — ProviderScope with override mirrors post-fix main.dart composition root
        await tester.pumpWidget(
          ProviderScope(
            overrides: _overrides(_repoWithBoard(_singleArrowBoard())),
            child: MaterialApp(
              theme: AppTheme.dark(),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              initialRoute: AppRouter.game,
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => GameScreen(levelId: LevelId('1')),
              ),
            ),
          ),
        );

        // Act — initState post-frame callback fires; loadLevel completes async
        await tester.pumpAndSettle();

        // Assert — board renders arrows, not SizedBox.shrink
        expect(find.byType(GameScreen), findsOneWidget);
        expect(find.byType(ArrowWidget), findsWidgets);
      },
    );

    // ── front#98: navegación terminal idempotente ────────────────────────────
    group('terminal navigation is idempotent (front#98)', () {
      GameWon won() => GameWon(
            moves: const MoveCount(1),
            score: Score(9000),
            stars: const Stars.three(),
            timeSeconds: 0,
            levelId: LevelId('level-01'),
            collisions: 0,
          );

      GameLost lost() => GameLost(
            moves: const MoveCount(0),
            strikes: const StrikeCount(5, max: 5),
          );

      testWidgets(
          'should_navigate_to_victory_once_when_GameWon_is_re_emitted',
          (tester) async {
        // Arrange — controller guionizado; el estado solo cambia por emit().
        final controller = _ScriptableGameController();
        final container =
            ProviderContainer(overrides: _overridesWith(() => controller));
        addTearDown(container.dispose);
        final observer = _TerminalNavObserver();
        await tester.pumpWidget(_observedHost(container, observer));
        await tester.pumpAndSettle(); // build() -> AsyncData(GameLoading)

        // Act — entra en victoria (borde) y luego RE-EMITE una nueva instancia
        // GameWon mientras GameScreen sigue montada (mitad de transición), como
        // haría el Observer de score al reconstruir el provider tras el POST.
        controller.emit(won());
        await tester.pump();
        controller.emit(won());
        await tester.pump();
        await tester.pumpAndSettle();

        // Assert — exactamente UNA navegación a la ruta de victoria.
        expect(observer.entries, [AppRouter.victory]);
        expect(find.byType(VictoryScreen), findsOneWidget);
      });

      testWidgets(
          'should_navigate_to_defeat_once_when_GameLost_is_re_emitted',
          (tester) async {
        // Arrange
        final controller = _ScriptableGameController();
        final container =
            ProviderContainer(overrides: _overridesWith(() => controller));
        addTearDown(container.dispose);
        final observer = _TerminalNavObserver();
        await tester.pumpWidget(_observedHost(container, observer));
        await tester.pumpAndSettle();

        // Act — misma re-emisión sobre el estado terminal simétrico.
        controller.emit(lost());
        await tester.pump();
        controller.emit(lost());
        await tester.pump();
        await tester.pumpAndSettle();

        // Assert — exactamente UNA navegación a la ruta de derrota.
        expect(observer.entries, [AppRouter.defeat]);
        expect(find.byType(DefeatScreen), findsOneWidget);
      });
    });

    // ── Rama de error: discrimina el LevelFailure (front#8, Task 10) ──────────
    group('error branch', () {
      testWidgets(
          'should_show_retry_and_reload_the_board_when_getLevel_returns_LevelUnavailable',
          (tester) async {
        // Arrange — el primer getLevel falla por falta de conexión sin caché.
        final repo = MockILevelRepository();
        when(repo.getLevel(any)).thenAnswer(
            (_) async => Left<LevelFailure, Level>(const LevelUnavailable()));
        await tester.pumpWidget(_errorHost(repo));
        await tester.pumpAndSettle(); // post-frame loadLevel -> AsyncError

        // Assert — copy offline + botón de reintento (FilledButton).
        expect(find.text("This level isn't available offline"), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Back to Levels'), findsNothing);

        // Act — al reintentar el repo ya responde el nivel jugable.
        when(repo.getLevel(any)).thenAnswer((_) async =>
            Right<LevelFailure, Level>(
                Level(id: LevelId('level-01'), board: _singleArrowBoard())));
        await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
        await tester.pumpAndSettle();

        // Assert — el tablero se renderiza y desaparece el mensaje de error.
        expect(find.byType(ArrowWidget), findsWidgets);
        expect(find.text("This level isn't available offline"), findsNothing);
      });

      testWidgets(
          'should_show_terminal_error_and_back_button_when_getLevel_returns_LevelNotFound',
          (tester) async {
        // Arrange — el back es autoridad: el nivel no existe (404).
        final repo = MockILevelRepository();
        when(repo.getLevel(any)).thenAnswer((_) async =>
            Left<LevelFailure, Level>(LevelNotFound(LevelId('level-01'))));
        await tester.pumpWidget(_errorHost(repo));
        await tester.pumpAndSettle(); // post-frame loadLevel -> AsyncError

        // Assert — copy terminal + "Back to Levels" (TextButton), sin reintento.
        expect(find.text("This level couldn't be loaded"), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Back to Levels'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);

        // Act — volver al selector de niveles.
        await tester.tap(find.widgetWithText(TextButton, 'Back to Levels'));
        await tester.pumpAndSettle();

        // Assert — navegó al selector; la pantalla de juego ya no está montada.
        expect(find.text('level-selection-stub'), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
      });

      testWidgets(
          'should_show_the_same_terminal_error_and_back_button_when_getLevel_returns_LevelCorrupted',
          (tester) async {
        // Arrange — el JSON no cumple el wire contract: dato corrupto.
        final repo = MockILevelRepository();
        when(repo.getLevel(any)).thenAnswer((_) async =>
            Left<LevelFailure, Level>(const LevelCorrupted('bad')));
        await tester.pumpWidget(_errorHost(repo));
        await tester.pumpAndSettle(); // post-frame loadLevel -> AsyncError

        // Assert — MISMA rama terminal que LevelNotFound: sin reintento.
        expect(find.text("This level couldn't be loaded"), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Back to Levels'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
      });
    });
  });
}
