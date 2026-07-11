import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
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

/// Monta VictoryScreen detras de una ruta que inyecta [VictoryArgs], tal como
/// hace el flujo real al ganar una partida.
Widget _appWith(VictoryArgs? args) => _localizedApp(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(arguments: args),
        builder: (_) => const VictoryScreen(),
      ),
    );

VictoryArgs _args({
  String level = '3',
  int moves = 5,
  int score = 10000,
  int stars = 3,
}) =>
    (levelId: LevelId(level), moves: moves, score: score, stars: stars);

/// Cuenta las estrellas "llenas" (pintadas con el color de logro) entre los 3
/// iconos, que es como la pantalla representa `stars` dinamicamente.
int _filledStars(WidgetTester tester) => tester
    .widgetList<Icon>(find.byIcon(Icons.star))
    .where((icon) => icon.color == AppColors.success)
    .length;

void main() {
  group('VictoryScreen', () {
    testWidgets(
        'should_render_three_filled_stars_and_score_when_won_with_three_stars',
        (tester) async {
      // Arrange
      await tester
          .pumpWidget(_appWith(_args(moves: 5, score: 10000, stars: 3)));

      // Act
      // (render only)

      // Assert
      expect(find.text('Board Cleared!'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(_filledStars(tester), 3);
      expect(find.text('Score: 10000'), findsOneWidget);
      expect(find.text('5 moves'), findsOneWidget);
    });

    testWidgets('should_render_one_filled_star_when_won_with_one_star',
        (tester) async {
      // Arrange
      await tester.pumpWidget(_appWith(_args(stars: 1)));

      // Act
      // (render only)

      // Assert: siempre 3 iconos, solo 1 lleno.
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(_filledStars(tester), 1);
    });

    testWidgets('should_fall_back_to_zero_and_disable_next_when_no_arguments',
        (tester) async {
      // Arrange
      await tester.pumpWidget(_appWith(null));

      // Act
      // (render only)

      // Assert
      expect(_filledStars(tester), 0);
      expect(find.text('Score: 0'), findsOneWidget);
      expect(find.text('0 moves'), findsOneWidget);
      final nextBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Next Level'));
      expect(nextBtn.onPressed, isNull);
    });

    testWidgets('should_navigate_to_next_level_id_when_next_level_tapped',
        (tester) async {
      // Arrange: nivel 3 en curso ⇒ el siguiente debe ser el 4.
      LevelId? pushedLevel;
      await tester.pumpWidget(
        _localizedApp(
          onGenerateRoute: (settings) => switch (settings.name) {
            AppRouter.game => MaterialPageRoute<void>(
                builder: (_) {
                  pushedLevel = settings.arguments as LevelId?;
                  return const Scaffold(body: Text('GAME'));
                },
              ),
            _ => MaterialPageRoute<void>(
                settings: RouteSettings(arguments: _args(level: '3')),
                builder: (_) => const VictoryScreen(),
              ),
          },
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Next Level'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('GAME'), findsOneWidget);
      expect(pushedLevel?.value, '4');
    });

    testWidgets('should_return_to_level_selection_when_back_to_levels_tapped',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        _localizedApp(
          onGenerateRoute: (settings) => switch (settings.name) {
            AppRouter.levelSelection => MaterialPageRoute<void>(
                builder: (_) => const LevelSelectionScreen(),
              ),
            _ => MaterialPageRoute<void>(
                settings: RouteSettings(arguments: _args()),
                builder: (_) => const VictoryScreen(),
              ),
          },
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(TextButton, 'Back to Levels'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });
  });
}
