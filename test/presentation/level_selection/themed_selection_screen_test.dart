import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/themed_selection_screen.dart';

import '../../support/level_selection_fakes.dart';

/// Captura el LevelId con el que se navega a la partida (o null si no se navegó).
class _NavCapture {
  LevelId? pushedLevel;
}

Widget _host(_NavCapture nav, {required List<Override> overrides}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ThemedSelectionScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.game) {
            nav.pushedLevel = settings.arguments as LevelId?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(key: Key('game-page')),
            );
          }
          return null;
        },
      ),
    );

/// Monta la pantalla y deja resolver el catálogo+progreso con pumps acotados
/// (el spinner anima siempre, así que `pumpAndSettle` colgaría).
Future<void> _pump(
  WidgetTester tester,
  _NavCapture nav,
  List<Override> overrides,
) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(nav, overrides: overrides));
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

/// Catálogo mixto: 3 de campaña + 2 temáticos. La sección temática debe pintar
/// SOLO los temáticos.
List<CatalogEntry> _mixedCatalog() => <CatalogEntry>[
      for (var n = 1; n <= 3; n++)
        CatalogEntry(id: LevelId('$n'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('t-heart'), section: LevelSection.themed),
      CatalogEntry(id: LevelId('t-smiley'), section: LevelSection.themed),
    ];

void main() {
  testWidgets('should_show_themed_title_and_only_themed_tiles', (tester) async {
    // Arrange & Act — catálogo mixto (campaña + temáticos).
    await _pump(
      tester,
      _NavCapture(),
      levelSelectionOverrides(catalogEntries: _mixedCatalog()),
    );

    // Assert — título de la sección + solo los 2 tiles temáticos (los de
    // campaña NO aparecen aquí), sin candados.
    expect(find.text('Themed'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-tile-t-heart')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-tile-t-smiley')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-tile-1')), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('should_launch_the_level_with_real_id_when_a_themed_tile_is_tapped',
      (tester) async {
    // Arrange
    final nav = _NavCapture();
    await _pump(
      tester,
      nav,
      levelSelectionOverrides(catalogEntries: _mixedCatalog()),
    );

    // Act — tocar el tile temático navega con el LevelId REAL.
    await tester.tap(find.byKey(const ValueKey('level-tile-t-smiley')));
    await tester.pump();
    await tester.pump();

    // Assert
    expect(nav.pushedLevel, LevelId('t-smiley'));
    expect(find.byKey(const Key('game-page')), findsOneWidget);
  });

  testWidgets('should_show_empty_state_when_catalog_has_no_themed_levels',
      (tester) async {
    // Arrange & Act — catálogo solo-campaña.
    await _pump(
      tester,
      _NavCapture(),
      levelSelectionOverrides(catalogIds: [for (var n = 1; n <= 3; n++) LevelId('$n')]),
    );

    // Assert — estado vacío, sin tiles.
    expect(find.text('No themed levels available yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-tile-1')), findsNothing);
  });
}
