import 'package:flutter/material.dart';
import 'package:flutter_arrow_maze/application/state/level_selection_controller.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/router/route_observer.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/level_selection_fakes.dart';

/// Captura el LevelId con el que se navega a la partida (o null si no se navegó).
class _NavCapture {
  LevelId? pushedLevel;
}

/// Repo de progreso que devuelve una instantánea distinta por llamada a
/// `getAll` (para simular que el progreso cambió entre entrada y entrada a la
/// pantalla). Al agotarse, repite la última.
class _SequencedProgress implements ILevelProgressRepository {
  final List<List<LevelProgress>> _snapshots;
  int _call = 0;
  _SequencedProgress(this._snapshots);
  @override
  Future<List<LevelProgress>> getAll() async {
    final i = _call < _snapshots.length ? _call : _snapshots.length - 1;
    _call++;
    return _snapshots[i];
  }

  @override
  Future<MoveCount?> getProgress(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) =>
      throw UnimplementedError();
  @override
  Future<void> markCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<bool> isCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> upsertAll(List<LevelProgress> progress) =>
      throw UnimplementedError();
}

/// Repo de progreso mutable: `getAll` refleja lo que haya en `data` en el
/// momento de la llamada (para simular que el progreso cambió mientras se jugaba
/// "encima" del selector).
class _MutableProgress implements ILevelProgressRepository {
  List<LevelProgress> data;
  _MutableProgress(this.data);
  @override
  Future<List<LevelProgress>> getAll() async => data;
  @override
  Future<MoveCount?> getProgress(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) =>
      throw UnimplementedError();
  @override
  Future<void> markCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<bool> isCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> upsertAll(List<LevelProgress> progress) =>
      throw UnimplementedError();
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

Widget _host(_NavCapture nav, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides.isEmpty
          ? [levelSelectionOverride(catalog: _catalog, progress: _progress)]
          : overrides,
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

/// Monta la pantalla y deja resolver el catálogo+progreso. La pantalla invalida
/// el provider tras el primer frame (recomposición al entrar), por lo que se
/// bombean varios frames acotados (evita `pumpAndSettle`, que colgaría con el
/// spinner). Fija una superficie alta para que ambos Tiers quepan sin scroll.
Future<void> _pumpScreen(
  WidgetTester tester,
  _NavCapture nav, {
  List<Override> overrides = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_host(nav, overrides: overrides));
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
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

  testWidgets(
      'should_refresh_gating_on_entry_so_a_newly_completed_tier_unlocks',
      (tester) async {
    // Arrange: al entrar, el progreso ya trae el Tier 1 completo (2ª lectura),
    // simulando el regreso de una partida ganada. La pantalla invalida el
    // provider al montarse, así que la 2ª lectura de `getAll` debe reflejarse.
    final progress = _SequencedProgress([
      const [], // 1ª lectura: sin progreso ⇒ Tier 2 bloqueado
      [
        LevelProgress(levelId: LevelId('1'), completed: true),
        LevelProgress(levelId: LevelId('2'), completed: true),
        LevelProgress(levelId: LevelId('3'), completed: true),
      ],
    ]);
    final override = levelSelectionControllerProvider.overrideWith(
      () => LevelSelectionController(
        FakeLevelCatalog(_catalog),
        progress,
        const TierGating(),
      ),
    );

    // Act
    await _pumpScreen(tester, _NavCapture(), overrides: [override]);

    // Assert: tras la recomposición al entrar, el Tier 2 quedó desbloqueado
    // (ya no hay candados) → el selector reflejó el progreso nuevo.
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('should_refresh_gating_when_revealed_after_pop_from_a_game',
      (tester) async {
    // Arrange: el selector permanece montado al fondo mientras se juega
    // "encima" (caso "Next Level" → back del dispositivo). El progreso cambia
    // durante la partida; al revelarse por `pop` debe recomponerse (RouteAware).
    await tester.binding.setSurfaceSize(const Size(500, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final progress =
        _MutableProgress(const []); // sin progreso ⇒ Tier 2 bloqueado
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          levelSelectionControllerProvider.overrideWith(
            () => LevelSelectionController(
              FakeLevelCatalog(_catalog),
              progress,
              const TierGating(),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [routeObserver],
          home: const LevelSelectionScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    // Sanity: al entrar, el Tier 2 está bloqueado.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));

    // Act: se "gana" el Tier 1 (cambia el progreso) mientras una ruta está
    // encima; luego se hace `pop` para revelar el selector.
    progress.data = [
      LevelProgress(levelId: LevelId('1'), completed: true),
      LevelProgress(levelId: LevelId('2'), completed: true),
      LevelProgress(levelId: LevelId('3'), completed: true),
    ];
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('GAME')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // fin push
    navKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // fin pop (reveal)
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    // Assert: el reveal por `pop` recompuso el selector → Tier 2 desbloqueado.
    expect(find.byIcon(Icons.lock), findsNothing);
  });
}
