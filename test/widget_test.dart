import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/auth/auth_gate.dart';
import 'package:flutter_arrow_maze/main.dart';

void main() {
  group('ArrowMazeApp', () {
    testWidgets('renders a MaterialApp guarded by AuthGate, with named game routes still resolvable',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(child: ArrowMazeApp()),
      );

      // Act
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));

      // Assert
      // front#15: el guard de ruta (AuthGate) reemplaza initialRoute como
      // home; onGenerateRoute se mantiene para que las rutas nombradas del
      // juego sigan resolviéndose dentro del subtree autenticado.
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(materialApp.home, isA<AuthGate>());
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

    testWidgets('configures i18n with es/en locales and localization delegates',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        const ProviderScope(child: ArrowMazeApp()),
      );

      // Act
      final materialApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));

      // Assert — front#4: el SO elige el idioma según el locale del dispositivo.
      expect(materialApp.localizationsDelegates, isNotNull);
      expect(materialApp.supportedLocales, contains(const Locale('es')));
      expect(materialApp.supportedLocales, contains(const Locale('en')));
    });
  });
}
