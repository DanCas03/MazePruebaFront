import 'package:flutter/material.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/level_selection_fakes.dart';

/// Captura el LevelId con el que se navega a la partida (o null si no se navegó).
class _NavCapture {
  LevelId? pushedLevel;
}

// Tier 1 desbloqueado (nivel 1 completado con 2★); Tier 1 incompleto ⇒ Tier 2
// bloqueado. Base para probar candado, estrellas y gating de navegación.
final _catalog = [
  levelDescriptor('1', Tier.one),
  levelDescriptor('2', Tier.one),
  levelDescriptor('3', Tier.one),
  levelDescriptor('4', Tier.two),
  levelDescriptor('5', Tier.two),
  levelDescriptor('6', Tier.two),
];
final _progress = [
  LevelProgress(levelId: LevelId('1'), completed: true, bestStars: 2),
];

Widget _host(_NavCapture nav) => ProviderScope(
      overrides: [
        levelSelectionOverride(catalog: _catalog, progress: _progress),
      ],
      child: MaterialApp(
        // La pantalla usa AppLocalizations (#4); sin delegates crashearía.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LevelSelectionScreen(),
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

/// Monta la pantalla y deja resolver el catálogo+progreso (evita `pumpAndSettle`,
/// que colgaría con el spinner de carga infinito). Fija una superficie alta para
/// que ambos Tiers quepan sin scroll (tap directo).
Future<void> _pumpScreen(WidgetTester tester, _NavCapture nav) async {
  await tester.binding.setSurfaceSize(const Size(500, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(nav));
  await tester.pump(); // resuelve getCatalog
  await tester.pump(); // resuelve getAll y reconstruye con data
}

void main() {
  testWidgets('should_show_lock_on_levels_of_locked_tier', (tester) async {
    // Arrange & Act
    await _pumpScreen(tester, _NavCapture());
    // Assert: los 3 niveles del Tier 2 (bloqueado) muestran candado.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));
  });

  testWidgets('should_render_earned_stars_on_completed_level', (tester) async {
    // Arrange & Act
    await _pumpScreen(tester, _NavCapture());
    // Assert: el nivel 1 aporta 2 estrellas llenas.
    expect(find.byIcon(Icons.star), findsNWidgets(2));
  });

  testWidgets('should_navigate_to_game_when_unlocked_level_tapped',
      (tester) async {
    // Arrange
    final nav = _NavCapture();
    await _pumpScreen(tester, nav);
    // Act
    await tester.tap(find.byKey(const ValueKey('level-tile-1')));
    await tester.pump();
    await tester.pump();
    // Assert
    expect(nav.pushedLevel, LevelId('1'));
    expect(find.byKey(const Key('game-page')), findsOneWidget);
  });

  testWidgets('should_not_navigate_when_locked_level_tapped', (tester) async {
    // Arrange
    final nav = _NavCapture();
    await _pumpScreen(tester, nav);
    // Act: el nivel 4 pertenece al Tier 2 bloqueado.
    await tester.tap(find.byKey(const ValueKey('level-tile-4')));
    await tester.pump();
    // Assert: ni navegó ni montó la página de juego.
    expect(nav.pushedLevel, isNull);
    expect(find.byKey(const Key('game-page')), findsNothing);
  });
}
