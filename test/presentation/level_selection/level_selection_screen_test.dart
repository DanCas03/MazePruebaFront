import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';

Widget _appUnderTest() {
  return MaterialApp(
    theme: AppTheme.dark(),
    initialRoute: AppRouter.levelSelection,
    onGenerateRoute: AppRouter.onGenerateRoute,
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
