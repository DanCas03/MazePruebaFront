import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/generated/configurator_screen.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/themed_selection_screen.dart';

import '../../support/level_selection_fakes.dart';

/// Construye una app minima centrada en HomeScreen, con el router real para
/// poder verificar la navegacion declarada por nombre de ruta. Locale fijado a
/// 'es' (front#4) para aserciones en español deterministas; el
/// LevelSelectionScreen destino exige sus providers compuestos (DIP, front#8:
/// Catálogo remoto + controller), inyectados con overrides de fakes.
Widget _appUnderTest() {
  return ProviderScope(
    overrides: levelSelectionOverrides(catalogIds: [LevelId('level-01')]),
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    ),
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
      expect(find.text('ARROW MAZE'), findsOneWidget);
      expect(find.text('Despeja el tablero. Saca cada flecha.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'JUGAR'), findsOneWidget);
    });

    testWidgets('Play navigates to LevelSelectionScreen', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'JUGAR'));
      // El logo del home anima en bucle infinito (repeat), así que
      // pumpAndSettle nunca se asentaría; bombeamos la transición de ruta
      // con pumps acotados.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });

    testWidgets('renders the "Niveles temáticos" CTA (front#100)',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());
      expect(find.widgetWithText(OutlinedButton, 'Niveles temáticos'),
          findsOneWidget);
    });

    testWidgets('"Niveles temáticos" navigates to ThemedSelectionScreen (front#100)',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Niveles temáticos'));
      // El logo anima en bucle: bombeamos la transición con pumps acotados.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ThemedSelectionScreen), findsOneWidget);
    });

    testWidgets('renders the "Generar nivel" CTA (front#37)', (tester) async {
      await tester.pumpWidget(_appUnderTest());
      expect(find.widgetWithText(OutlinedButton, 'Generar nivel'),
          findsOneWidget);
    });

    testWidgets('"Generar nivel" navigates to ConfiguratorScreen (front#37)',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Generar nivel'));
      // El logo anima en bucle: bombeamos la transición con pumps acotados.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ConfiguratorScreen), findsOneWidget);
    });
  });
}
