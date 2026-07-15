import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

import '../../support/level_selection_fakes.dart';

LevelProgress _done(String id) =>
    LevelProgress(levelId: LevelId(id), completed: true);

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
  List<LevelId> catalogIds = const [],
  List<CatalogEntry>? catalogEntries,
  List<LevelProgress> progress = const [],
  List<RouteSettings>? pushed,
}) {
  return ProviderScope(
    overrides: [
      stubCatalogOverride(ids: catalogIds, entries: catalogEntries),
      // El CTA "Next Level" ahora respeta el gating (front#81): la pantalla lee
      // el progreso local para decidir si el siguiente Tier está abierto.
      levelProgressRepositoryProvider
          .overrideWithValue(FakeLevelProgressRepository(progress)),
    ],
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

    testWidgets(
        'should_suppress_next_level_and_campaign_complete_for_a_themed_level',
        (tester) async {
      // Arrange & Act: el nivel jugado es temático (no está entre los de
      // campaña del Catálogo). No tiene adyacencia de "siguiente nivel".
      final catalog = <CatalogEntry>[
        CatalogEntry(id: LevelId('level-01'), section: LevelSection.campaign),
        CatalogEntry(id: LevelId('level-02'), section: LevelSection.campaign),
        CatalogEntry(id: LevelId('t-smiley'), section: LevelSection.themed),
      ];
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 't-smiley'),
          catalogEntries: catalog,
        ),
      );
      await tester.pumpAndSettle();

      // Assert: ni CTA "Next Level" ni felicitación de campaña; solo el regreso.
      expect(find.text('Next Level'), findsNothing);
      expect(find.text("You've completed all levels!"), findsNothing);
      expect(find.widgetWithText(TextButton, 'Back to Levels'), findsOneWidget);
    });

    testWidgets(
        'should_offer_next_level_over_campaign_ids_when_themed_are_interleaved',
        (tester) async {
      // Arrange: la campaña es level-01 → level-02; el temático intercalado no
      // debe contar como "siguiente" de level-01.
      final pushed = <RouteSettings>[];
      final catalog = <CatalogEntry>[
        CatalogEntry(id: LevelId('level-01'), section: LevelSection.campaign),
        CatalogEntry(id: LevelId('t-smiley'), section: LevelSection.themed),
        CatalogEntry(id: LevelId('level-02'), section: LevelSection.campaign),
      ];
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 'level-01'),
          catalogEntries: catalog,
          pushed: pushed,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Next Level'));
      await tester.pumpAndSettle();

      // Assert: el siguiente de campaña es level-02, saltando el temático.
      expect(pushed.single.arguments, LevelId('level-02'));
    });

    // Catálogo de 6 niveles de campaña ⇒ Tier.one = 1..3, Tier.two = 4..6.
    final twoTierIds = [for (var i = 1; i <= 6; i++) LevelId('level-0$i')];

    testWidgets(
        'should_hide_next_level_and_show_lock_message_when_next_tier_is_locked',
        (tester) async {
      // Arrange & Act: se gana el ÚLTIMO del Tier.one (level-03) SIN haber
      // completado los niveles 1 y 2 (entrada fuera de orden). El siguiente
      // (level-04) es del Tier.two, que sigue bloqueado. Regresión del bug #81.
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 'level-03'),
          catalogIds: twoTierIds,
          progress: const [],
          pushed: pushed,
        ),
      );
      await tester.pumpAndSettle();

      // Assert: NO se ofrece "Next Level"; se muestra el requisito de desbloqueo.
      expect(find.text('Next Level'), findsNothing);
      expect(
        find.text('Complete the earlier levels to unlock the next one.'),
        findsOneWidget,
      );
      expect(pushed, isEmpty);
    });

    testWidgets(
        'should_offer_next_level_when_previous_levels_unlock_the_next_tier',
        (tester) async {
      // Arrange: niveles 1 y 2 completados; se gana el 3 (último del Tier.one).
      // Con el 3 recién ganado, el Tier.two abre ⇒ level-04 es jugable.
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        _appUnderTest(
          args: _args(level: 'level-03'),
          catalogIds: twoTierIds,
          progress: [_done('level-01'), _done('level-02')],
          pushed: pushed,
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Next Level'));
      await tester.pumpAndSettle();

      // Assert: navega al primer nivel del Tier.two (level-04).
      expect(pushed, hasLength(1));
      expect(pushed.single.name, AppRouter.game);
      expect(pushed.single.arguments, LevelId('level-04'));
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
