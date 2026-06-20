import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';

/// Generador falso: el GameScreen es ahora un ConsumerWidget, por lo que la
/// navegacion hacia el exige un ProviderScope con el provider compuesto. Para
/// este test (solo verifica que se llega a la pantalla) basta un tablero vacio.
class _EmptyBoardGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) =>
      const ArrowBoard(arrows: [], cols: 4, rows: 4);
}

Widget _appUnderTest() {
  return ProviderScope(
    overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
          _EmptyBoardGenerator(),
          RemoveArrowUseCase(),
          CommandInvoker(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      initialRoute: AppRouter.levelSelection,
      onGenerateRoute: AppRouter.onGenerateRoute,
    ),
  );
}

void main() {
  group('LevelSelectionScreen', () {
    testWidgets('renders a lazy grid of selectable level tiles',
        (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      // (render only)

      // Assert: GridView.builder es perezoso, asi que solo afirmamos que la
      // cuadricula existe y que el primer nivel se renderiza como tile tocable.
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(InkWell), findsWidgets);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('scrolls to reveal the last level (12)', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      await tester.drag(find.byType(GridView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('tapping a level navigates to the GameScreen', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(GameScreen), findsOneWidget);
    });
  });
}
