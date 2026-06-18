import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';

/// Construye una app minima centrada en HomeScreen, con el router real para
/// poder verificar la navegacion declarada por nombre de ruta.
Widget _appUnderTest() {
  return MaterialApp(
    theme: AppTheme.dark(),
    initialRoute: AppRouter.home,
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders title, tagline and the Play CTA', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      // (render only)

      // Assert
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Arrow Maze'), findsOneWidget);
      expect(find.text('Clear the board'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    });

    testWidgets('Play navigates to LevelSelectionScreen', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Play'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });
  });
}
