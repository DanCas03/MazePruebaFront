import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/generated/configurator_screen.dart';

/// App mínima centrada en el configurador. No compone el controlador de juego
/// generado porque estas pruebas no navegan a "Jugar"; solo verifican la
/// habilitación reactiva del CTA (criterio de aceptación #37).
Widget _appUnderTest() {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ConfiguratorScreen(),
    ),
  );
}

FilledButton _playButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Jugar'));

void main() {
  group('ConfiguratorScreen', () {
    testWidgets('muestra selectores, dificultad, contrarreloj y semilla',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());

      expect(find.text('Columnas'), findsOneWidget);
      expect(find.text('Filas'), findsOneWidget);
      // Segmentos de dificultad (easy/medium/hard) con sus etiquetas es.
      expect(find.text('Fácil'), findsOneWidget);
      expect(find.text('Medio'), findsOneWidget);
      expect(find.text('Difícil'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(find.text('Semilla (opcional)'), findsOneWidget);
    });

    testWidgets('"Jugar" está habilitado por defecto (semilla vacía)',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());
      expect(_playButton(tester).onPressed, isNotNull);
    });

    testWidgets('semilla no numérica deshabilita "Jugar" y muestra el error',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());

      // "1-2" pasa el filtro de entrada (dígitos y '-') pero no es un entero.
      await tester.enterText(find.byType(TextField), '1-2');
      await tester.pump();

      expect(_playButton(tester).onPressed, isNull);
      expect(find.text('La semilla debe ser un número entero'), findsOneWidget);
    });

    testWidgets('corregir la semilla vuelve a habilitar "Jugar"',
        (tester) async {
      await tester.pumpWidget(_appUnderTest());

      await tester.enterText(find.byType(TextField), '-');
      await tester.pump();
      expect(_playButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '77');
      await tester.pump();
      expect(_playButton(tester).onPressed, isNotNull);
    });
  });
}
