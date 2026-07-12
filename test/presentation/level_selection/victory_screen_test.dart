import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

import '../../support/level_selection_fakes.dart';

VictoryArgs _args({
  String level = 'level-01',
  int moves = 5,
  int score = 10000,
  int stars = 3,
}) =>
    (levelId: LevelId(level), moves: moves, score: score, stars: stars);

/// Cuenta las estrellas "llenas" (pintadas con el color de logro) entre los 3
/// iconos, que es como la pantalla representa `stars` dinámicamente.
int _filledStars(WidgetTester tester) => tester
    .widgetList<Icon>(find.byIcon(Icons.star))
    .where((icon) => icon.color == AppColors.success)
    .length;

/// Monta la `VictoryScreen` real detrás de la ruta por defecto, que le inyecta
/// los [VictoryArgs] via `settings.arguments` (tal como hace el flujo real al
/// ganar). El Catálogo se fija en [catalogIds] mediante un `ProviderScope`. Cada
/// navegación posterior (game / levelSelection) se registra en [pushed] para
/// aseverar destino y `arguments` (el `LevelId` real) sin montar pantallas
/// reales.
Widget _appUnderTest({
  required VictoryArgs? args,
  required List<LevelId> catalogIds,
  List<RouteSettings>? pushed,
}) {
  return ProviderScope(
    overrides: [stubCatalogOverride(ids: catalogIds)],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      onGenerateRoute: (settings) {
        // Navegaciones de salida: se registran y se sirven con un placeholder.
        if (settings.name == AppRouter.game ||
            settings.name == AppRouter.levelSelection) {
          pushed?.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: SizedBox.shrink()),
          );
        }
        // Ruta por defecto ('/'): la VictoryScreen real con sus VictoryArgs.
        return MaterialPageRoute<void>(
          settings: RouteSettings(name: settings.name, arguments: args),
          builder: (_) => const VictoryScreen(),
        );
      },
    ),
  );
}

void main() {
  group('VictoryScreen', () {
    final ids = [LevelId('level-01'), LevelId('level-02'), LevelId('level-03')];

    testWidgets(
        'should_show_next_level_and_hide_campaign_complete_when_on_a_middle_level',
        (tester) async {
      // Arrange & Act: nivel intermedio (level-01) con el Catálogo cargado.
      await tester.pumpWidget(
        _appUnderTest(args: _args(level: 'level-01'), catalogIds: ids),
      );
      await tester.pumpAndSettle();

      // Assert: hay CTA "Next Level" y NO aparece la felicitación de campaña.
      expect(find.widgetWithText(FilledButton, 'Next Level'), findsOneWidget);
      expect(find.text("You've completed all levels!"), findsNothing);
    });

    testWidgets(
        'should_navigate_to_the_next_catalog_id_when_next_level_is_tapped',
        (tester) async {
      // Arrange: level-01 en curso ⇒ el siguiente del Catálogo es level-02.
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 'level-01'),
          catalogIds: ids,
          pushed: pushed,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Next Level'));
      await tester.pumpAndSettle();

      // Assert: pushReplacementNamed(game) con el SIGUIENTE id (level-02).
      expect(pushed, hasLength(1));
      expect(pushed.single.name, AppRouter.game);
      expect(pushed.single.arguments, LevelId('level-02'));
    });

    testWidgets(
        'should_hide_next_level_and_show_campaign_complete_when_on_the_last_level',
        (tester) async {
      // Arrange & Act: último nivel del Catálogo (level-03).
      await tester.pumpWidget(
        _appUnderTest(args: _args(level: 'level-03'), catalogIds: ids),
      );
      await tester.pumpAndSettle();

      // Assert: sin CTA "Next Level"; se muestra la felicitación de campaña.
      expect(find.text('Next Level'), findsNothing);
      expect(find.text("You've completed all levels!"), findsOneWidget);
    });

    testWidgets(
        'should_navigate_to_level_selection_when_back_to_levels_is_tapped',
        (tester) async {
      // Arrange: el botón "Back to Levels" está siempre presente.
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 'level-01'),
          catalogIds: ids,
          pushed: pushed,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Back to Levels'), findsOneWidget);

      // Act
      await tester.tap(find.widgetWithText(TextButton, 'Back to Levels'));
      await tester.pumpAndSettle();

      // Assert: navega a la selección de niveles.
      expect(pushed, hasLength(1));
      expect(pushed.single.name, AppRouter.levelSelection);
    });

    testWidgets('should_render_score_moves_and_matching_filled_stars_when_won',
        (tester) async {
      // Arrange & Act: victoria con 2 de 3 estrellas, score y moves conocidos.
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 'level-01', moves: 7, score: 1234, stars: 2),
          catalogIds: ids,
        ),
      );
      await tester.pumpAndSettle();

      // Assert: textos de score/moves y exactamente 2 de 3 estrellas llenas.
      expect(find.text('Score: 1234'), findsOneWidget);
      expect(find.text('7 moves'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(3));
      expect(_filledStars(tester), 2);
    });
  });
}
