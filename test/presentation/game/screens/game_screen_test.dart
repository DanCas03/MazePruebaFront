import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/providers/leaderboard_providers.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/submit_score_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/logger_service_adapter.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/defeat_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

/// Genera un tablero con una unica flecha de salida libre, de modo que al
/// taparla el tablero queda limpio y el juego transita a GameWon.
class _SingleArrowGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    return ArrowBoard(
      cols: 4,
      rows: 4,
      arrows: [
        Arrow.straight(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.left,
          length: 1,
        ),
      ],
    );
  }
}

/// Genera un tablero cuya flecha objetivo ('a1') tiene la salida bloqueada por
/// una segunda flecha en su carril: cada tap sobre 'a1' es un choque, de modo
/// que 5 taps llevan el juego a GameLost sin vaciar el tablero.
class _BlockedArrowGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    return ArrowBoard(
      cols: 4,
      rows: 4,
      arrows: [
        // Sale hacia la derecha; su exitPath incluye (0,3).
        Arrow.straight(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        // Ocupa (0,3) → bloquea la salida de 'a1'.
        Arrow.straight(
          id: const ArrowId('blk'),
          tail: Position(row: 0, col: 3),
          direction: Direction.right,
          length: 1,
        ),
      ],
    );
  }
}

/// Repo de leaderboard no-op: los widget tests activan el Observer de envío de
/// score (front#16) pero no ejercen la red.
class _NoopLeaderboardRepository implements ILeaderboardRepository {
  @override
  Future<void> submitScore(ScoreEntry entry) async {}
}

ProviderContainer _container([ILevelGenerator? generator]) =>
    ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
          generator ?? _SingleArrowGenerator(),
          RemoveArrowUseCase(),
          CommandInvoker(),
        ),
      ),
      submitScoreUseCaseProvider.overrideWithValue(
        SubmitScoreUseCase(_NoopLeaderboardRepository(), LoggerServiceAdapter()),
      ),
    ]);

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

void main() {
  group('GameScreen', () {
    testWidgets('shows the moves counter while playing', (tester) async {
      // Arrange
      final container = _container();
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

    testWidgets('shows the countdown for a timed level', (tester) async {
      // Arrange — nivel cronometrado (90 s). Con el reloj por defecto (inerte)
      // el estado conserva el límite inicial, suficiente para verificar el render.
      final container = _container();
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
      // Arrange — nivel 1 no tiene límite de tiempo.
      final container = _container();
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
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
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
      final container = _container(_BlockedArrowGenerator());
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

    // BUG-2 regression: provider not overridden + loadLevel never called on mount
    testWidgets(
      'BUG-2 regression: navigating to /game via router renders board without manual loadLevel call',
      (tester) async {
        // Arrange — ProviderScope with override mirrors post-fix main.dart composition root
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameControllerProvider.overrideWith(
                () => GameController(
                  _SingleArrowGenerator(),
                  RemoveArrowUseCase(),
                  CommandInvoker(),
                ),
              ),
              submitScoreUseCaseProvider.overrideWithValue(
                SubmitScoreUseCase(
                    _NoopLeaderboardRepository(), LoggerServiceAdapter()),
              ),
            ],
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
  });
}
