import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

/// MaterialApp localizada (front#4): locale 'en' fijo para aserciones en inglés.
Widget _localizedApp({required RouteFactory onGenerateRoute}) => MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: onGenerateRoute,
    );

/// Monta VictoryScreen detras de una ruta que inyecta `arguments` (numero de
/// movimientos), tal como hace el flujo real al ganar una partida.
Widget _appWithMoves(int? moves) {
  return _localizedApp(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      settings: RouteSettings(arguments: moves),
      builder: (_) => const VictoryScreen(),
    ),
  );
}

void main() {
  group('VictoryScreen', () {
    testWidgets('shows the moves passed as route arguments', (tester) async {
      // Arrange
      await tester.pumpWidget(_appWithMoves(7));

      // Act
      // (render only)

      // Assert
      expect(find.text('Board Cleared!'), findsOneWidget);
      expect(find.text('7 moves'), findsOneWidget);
    });

    testWidgets('falls back to 0 moves when no arguments are provided',
        (tester) async {
      // Arrange
      await tester.pumpWidget(_appWithMoves(null));

      // Act
      // (render only)

      // Assert
      expect(find.text('0 moves'), findsOneWidget);
    });

    testWidgets('Back to Levels returns to LevelSelectionScreen',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        _localizedApp(
          onGenerateRoute: (settings) => switch (settings.name) {
            '/levels' => MaterialPageRoute<void>(
                builder: (_) => const LevelSelectionScreen(),
              ),
            _ => MaterialPageRoute<void>(
                settings: const RouteSettings(arguments: 3),
                builder: (_) => const VictoryScreen(),
              ),
          },
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Back to Levels'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });
  });
}
