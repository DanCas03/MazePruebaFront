import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

/// Genera un tablero con una unica flecha de salida libre, de modo que al
/// taparla el tablero queda limpio y el juego transita a GameWon.
class _SingleArrowGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
  }) {
    return ArrowBoard(
      cols: 4,
      rows: 4,
      arrows: [
        Arrow(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.left,
          length: ArrowLength(1),
        ),
      ],
    );
  }
}

ProviderContainer _container() => ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
          _SingleArrowGenerator(),
          RemoveArrowUseCase(),
          CommandInvoker(),
        ),
      ),
    ]);

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        onGenerateRoute: (settings) => switch (settings.name) {
          AppRouter.victory => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const VictoryScreen(),
            ),
          _ => MaterialPageRoute<void>(builder: (_) => const GameScreen()),
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
  });
}
