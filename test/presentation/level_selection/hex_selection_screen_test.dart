import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/hex_selection_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/widgets/level_tile_view.dart';

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
        home: const HexSelectionScreen(),
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

/// Catálogo mixto: 1 de campaña + 1 temático + 3 hex. La sección hex debe
/// pintar SOLO los hex.
List<CatalogEntry> _mixedCatalog() => <CatalogEntry>[
      CatalogEntry(id: LevelId('1'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('t-heart'), section: LevelSection.themed),
      CatalogEntry(id: LevelId('hex-01'), section: LevelSection.hex),
      CatalogEntry(id: LevelId('hex-02'), section: LevelSection.hex),
      CatalogEntry(id: LevelId('hex-03'), section: LevelSection.hex),
    ];

void main() {
  testWidgets('should_list_exactly_hex_section_tiles_all_enabled',
      (tester) async {
    // Arrange & Act — catálogo mixto (campaña + temático + hex).
    await _pump(
      tester,
      _NavCapture(),
      levelSelectionOverrides(catalogEntries: _mixedCatalog()),
    );

    // Assert — solo las 3 fichas hex, ninguna bloqueada.
    expect(find.byType(LevelTileView), findsNWidgets(3));
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('should_navigate_to_game_with_real_level_id_on_tap',
      (tester) async {
    // Arrange
    final nav = _NavCapture();
    await _pump(
      tester,
      nav,
      levelSelectionOverrides(
        catalogEntries: [
          CatalogEntry(id: LevelId('hex-01'), section: LevelSection.hex),
        ],
      ),
    );

    // Act — tocar la ficha hex navega con el LevelId REAL.
    await tester.tap(find.byKey(const ValueKey('level-tile-hex-01')));
    await tester.pump();
    await tester.pump();

    // Assert
    expect(nav.pushedLevel, LevelId('hex-01'));
    expect(find.byKey(const Key('game-page')), findsOneWidget);
  });

  testWidgets('should_show_empty_state_when_no_hex_levels', (tester) async {
    // Arrange & Act — catálogo sin entries hex.
    await _pump(
      tester,
      _NavCapture(),
      levelSelectionOverrides(
        catalogEntries: [
          CatalogEntry(id: LevelId('1'), section: LevelSection.campaign),
          CatalogEntry(id: LevelId('t-heart'), section: LevelSection.themed),
        ],
      ),
    );

    // Assert — estado vacío, sin tiles.
    expect(find.text('No hex levels available yet.'), findsOneWidget);
  });

  testWidgets('should_show_error_state_when_catalog_fails', (tester) async {
    // Arrange & Act — el Catálogo remoto falla.
    await _pump(
      tester,
      _NavCapture(),
      [
        stubCatalogOverride(
          builder: () => throw const LevelUnavailable(),
        ),
        levelSelectionControllerOverride(),
      ],
    );

    // Assert
    expect(find.text("Couldn't load levels"), findsOneWidget);
  });
}
