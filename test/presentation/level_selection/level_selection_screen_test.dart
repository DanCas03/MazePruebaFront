import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/router/route_observer.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
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

// Catálogo remoto de 6 ids: por POSICIÓN, 1-3 → Tier 1 y 4-6 → Tier 2. Con el
// nivel 1 completado (2★) el Tier 1 está desbloqueado pero incompleto ⇒ Tier 2
// bloqueado. Base para probar candado, estrellas y gating de navegación.
final _catalogIds = [for (var n = 1; n <= 6; n++) LevelId('$n')];
final _progress = [
  LevelProgress(levelId: LevelId('1'), completed: true, bestStars: 2),
];

Widget _host(_NavCapture nav, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides.isEmpty
          ? levelSelectionOverrides(
              catalogIds: _catalogIds, progress: _progress)
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

  testWidgets(
      'should_not_embed_the_themed_block_the_campaign_selector_is_campaign_only',
      (tester) async {
    // Arrange & Act — catálogo con un temático: el selector de campaña ya NO lo
    // embebe (front#100: el contenido temático vive en ThemedSelectionScreen).
    final entries = <CatalogEntry>[
      for (var n = 1; n <= 3; n++)
        CatalogEntry(id: LevelId('$n'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('t-smiley'), section: LevelSection.themed),
    ];
    await _pumpScreen(
      tester,
      _NavCapture(),
      overrides: levelSelectionOverrides(catalogEntries: entries),
    );
    // Assert — ni encabezado "Themed" ni la celda temática en esta pantalla.
    expect(find.text('Themed'), findsNothing);
    expect(find.byKey(const ValueKey('level-tile-t-smiley')), findsNothing);
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
      'should_show_position_and_navigate_with_real_id_when_ids_are_opaque',
      (tester) async {
    // Arrange: ids del back opacos (front#8): la celda muestra la POSICIÓN.
    final nav = _NavCapture();
    final opaqueIds = [
      LevelId('level-01'),
      LevelId('level-02'),
      LevelId('level-03'),
    ];
    await _pumpScreen(
      tester,
      nav,
      overrides: levelSelectionOverrides(catalogIds: opaqueIds),
    );
    // Assert: etiquetas por posición, no por id.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('level-01'), findsNothing);

    // Act: la primera celda muestra '1' pero debe navegar con el id REAL.
    await tester.tap(find.byKey(const ValueKey('level-tile-level-01')));
    await tester.pump();
    await tester.pump();
    // Assert
    expect(nav.pushedLevel, LevelId('level-01'));
  });

  testWidgets('should_show_spinner_when_catalog_is_loading', (tester) async {
    // Arrange: un build() del Catálogo que nunca resuelve mantiene el loading.
    final pending = Completer<List<CatalogEntry>>();
    final overrides = [
      stubCatalogOverride(builder: () => pending.future),
      levelSelectionControllerOverride(),
    ];

    // Act: pumps acotados (nunca `pumpAndSettle`: el spinner anima siempre).
    await _pumpScreen(tester, _NavCapture(), overrides: overrides);

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should_show_error_and_retry_when_catalog_fails',
      (tester) async {
    // Arrange
    final overrides = [
      stubCatalogOverride(builder: () => throw const LevelUnavailable()),
      levelSelectionControllerOverride(),
    ];

    // Act
    await _pumpScreen(tester, _NavCapture(), overrides: overrides);

    // Assert: mensaje localizado + botón de reintentar con su etiqueta.
    expect(find.text("Couldn't load levels"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('should_reload_catalog_when_retry_is_tapped', (tester) async {
    // Arrange: arranca en error; al reintentar (refresh → build) hay datos.
    var shouldFail = true;
    final overrides = [
      stubCatalogOverride(builder: () {
        if (shouldFail) throw const LevelUnavailable();
        return campaignEntries(_catalogIds);
      }),
      levelSelectionControllerOverride(),
    ];
    await _pumpScreen(tester, _NavCapture(), overrides: overrides);
    expect(find.byIcon(Icons.lock), findsNothing); // precondición: estado error
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    shouldFail = false; // el back ya responde

    // Act: tocar reintentar dispara refresh() → re-ejecuta build().
    await tester.tap(find.byType(FilledButton));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }

    // Assert: el refresh recargó el Catálogo y las secciones aparecen.
    expect(find.text('Tier 1'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
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
    final overrides = levelSelectionOverrides(
      catalogIds: _catalogIds,
      progressRepository: progress,
    );

    // Act
    await _pumpScreen(tester, _NavCapture(), overrides: overrides);

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
        overrides: levelSelectionOverrides(
          catalogIds: _catalogIds,
          progressRepository: progress,
        ),
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
