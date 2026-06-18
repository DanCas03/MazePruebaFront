import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/main.dart';

void main() {
  group('ArrowMazeApp', () {
    testWidgets('renders a MaterialApp wired to the AppRouter home route',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(child: ArrowMazeApp()),
      );

      // Act
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));

      // Assert
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(materialApp.initialRoute, AppRouter.home);
      expect(materialApp.onGenerateRoute, isNotNull);
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
    });

    testWidgets('exposes both light and dark themes following the system',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(child: ArrowMazeApp()),
      );

      // Act
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));

      // Assert
      expect(materialApp.theme, isNotNull);
      expect(materialApp.darkTheme, isNotNull);
      expect(materialApp.theme!.brightness, Brightness.light);
      expect(materialApp.darkTheme!.brightness, Brightness.dark);
      expect(materialApp.themeMode, ThemeMode.system);
    });
  });
}
