import 'package:flutter_arrow_maze/application/providers/level_catalog_provider.dart';
import 'package:flutter_arrow_maze/application/state/level_selection_controller.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/level_selection_fakes.dart';

ProviderContainer _containerWith(
  List<LevelId> catalogIds,
  List<LevelProgress> progress,
) {
  final container = ProviderContainer(
    overrides:
        levelSelectionOverrides(catalogIds: catalogIds, progress: progress),
  );
  addTearDown(container.dispose);
  return container;
}

ProviderContainer _containerWithEntries(
  List<CatalogEntry> entries,
  List<LevelProgress> progress,
) {
  final container = ProviderContainer(
    overrides: levelSelectionOverrides(
        catalogEntries: entries, progress: progress),
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Catálogo remoto de 6 ids: por POSICIÓN, 1-3 → Tier.one y 4-6 → Tier.two.
  final catalogIds = [for (var n = 1; n <= 6; n++) LevelId('$n')];

  test('should_group_tiles_into_sections_by_tier_when_built', () async {
    // Arrange
    final container = _containerWith(catalogIds, const []);
    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);
    final sections = view.campaignTiers;
    // Assert
    expect(sections.length, 2);
    expect(sections[0].tier, Tier.one);
    expect(sections[0].tiles.length, 3);
    expect(sections[1].tier, Tier.two);
  });

  test('should_derive_tier_and_position_from_catalog_order_when_ids_are_opaque',
      () async {
    // Arrange: ids del back NO numéricos → el orden del Catálogo es la única
    // fuente de posición/Tier (glosario: nunca aritmética sobre el id).
    final opaqueIds = [
      LevelId('level-a'),
      LevelId('level-b'),
      LevelId('level-c'),
      LevelId('level-d'),
    ];
    final container = _containerWith(opaqueIds, const []);
    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);
    final sections = view.campaignTiers;
    // Assert: 3 primeros en Tier.one; el 4º abre Tier.two; posiciones 1..4.
    expect(sections[0].tier, Tier.one);
    expect(sections[0].tiles.map((t) => t.position), [1, 2, 3]);
    expect(sections[1].tier, Tier.two);
    expect(sections[1].tiles.single.position, 4);
    expect(sections[1].tiles.single.levelId, LevelId('level-d'));
  });

  test('should_expose_best_stars_when_progress_has_them', () async {
    // Arrange
    final progress = [
      LevelProgress(levelId: LevelId('1'), completed: true, bestStars: 2),
    ];
    final container = _containerWith(catalogIds, progress);
    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);
    final sections = view.campaignTiers;
    // Assert
    final tile1 = sections[0].tiles.firstWhere((t) => t.levelId.value == '1');
    expect(tile1.stars, 2);
  });

  test('should_default_stars_to_zero_when_completed_without_best_stars',
      () async {
    // Arrange: completado pero sin ScoreEntry aún (bestStars null).
    final progress = [LevelProgress(levelId: LevelId('1'), completed: true)];
    final container = _containerWith(catalogIds, progress);
    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);
    final sections = view.campaignTiers;
    // Assert
    final tile1 = sections[0].tiles.firstWhere((t) => t.levelId.value == '1');
    expect(tile1.stars, 0);
  });

  test('should_lock_second_tier_when_first_tier_incomplete', () async {
    // Arrange
    final container = _containerWith(catalogIds, const []);
    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);
    final sections = view.campaignTiers;
    // Assert
    expect(sections[0].tiles.every((t) => !t.locked), isTrue);
    expect(sections[1].tiles.every((t) => t.locked), isTrue);
  });

  test('should_unlock_second_tier_when_all_first_tier_levels_completed',
      () async {
    // Arrange
    final progress = [
      LevelProgress(levelId: LevelId('1'), completed: true),
      LevelProgress(levelId: LevelId('2'), completed: true),
      LevelProgress(levelId: LevelId('3'), completed: true),
    ];
    final container = _containerWith(catalogIds, progress);
    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);
    final sections = view.campaignTiers;
    // Assert
    expect(sections[1].tiles.every((t) => !t.locked), isTrue);
  });

  test('should_surface_catalog_failure_as_error_state_when_catalog_throws',
      () async {
    // Arrange: el Catálogo remoto falla (sin red y sin caché) → el selector
    // debe quedar en error para que la UI ofrezca reintentar.
    final container = ProviderContainer(
      overrides: [
        levelCatalogProvider.overrideWith(
          () => StubLevelCatalog.withBuilder(
            () => throw const LevelUnavailable(),
          ),
        ),
        levelSelectionControllerProvider.overrideWith(
          () => LevelSelectionController(
            const FakeLevelProgressRepository(),
            const TierGating(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Act & Assert: la caída del Catálogo se propaga como error del selector.
    await expectLater(
      container.read(levelSelectionControllerProvider.future),
      throwsA(isA<LevelUnavailable>()),
    );
  });

  test('should_expose_themed_entries_as_tiles_without_locks', () async {
    // Arrange: dos niveles temáticos (sin gating). El progreso NO los desbloquea
    // porque nunca están bloqueados.
    final entries = [
      CatalogEntry(id: LevelId('t-smiley'), section: LevelSection.themed),
      CatalogEntry(id: LevelId('t-heart'), section: LevelSection.themed),
    ];
    final container = _containerWithEntries(entries, const []);
    // Act
    final view = await container.read(levelSelectionControllerProvider.future);
    // Assert: aparecen como themedTiles, ninguno bloqueado, sin secciones de Tier.
    expect(view.campaignTiers, isEmpty);
    expect(view.themedTiles.length, 2);
    expect(view.themedTiles.every((t) => !t.locked), isTrue);
    expect(view.themedTiles.map((t) => t.levelId),
        [LevelId('t-smiley'), LevelId('t-heart')]);
  });

  test('should_not_shift_campaign_tiers_when_themed_entries_are_interleaved',
      () async {
    // Arrange: 6 niveles de campaña intercalados con temáticos. El Tier se
    // deriva de la posición ENTRE los de campaña, así que los temáticos no lo
    // desplazan (1-3 → Tier.one, 4-6 → Tier.two), idéntico a un catálogo puro.
    final entries = <CatalogEntry>[
      CatalogEntry(id: LevelId('1'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('t-a'), section: LevelSection.themed),
      CatalogEntry(id: LevelId('2'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('3'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('t-b'), section: LevelSection.themed),
      CatalogEntry(id: LevelId('4'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('5'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('6'), section: LevelSection.campaign),
    ];
    final container = _containerWithEntries(entries, const []);
    // Act
    final view = await container.read(levelSelectionControllerProvider.future);
    // Assert: la campaña conserva sus dos Tiers con 3 celdas cada uno y
    // posiciones 1..6 (agnósticas a los temáticos); 2 tiles temáticos aparte.
    expect(view.campaignTiers.length, 2);
    expect(view.campaignTiers[0].tier, Tier.one);
    expect(view.campaignTiers[0].tiles.map((t) => t.position), [1, 2, 3]);
    expect(view.campaignTiers[0].tiles.map((t) => t.levelId),
        [LevelId('1'), LevelId('2'), LevelId('3')]);
    expect(view.campaignTiers[1].tier, Tier.two);
    expect(view.campaignTiers[1].tiles.map((t) => t.position), [4, 5, 6]);
    expect(view.themedTiles.length, 2);
  });

  test('should_expose_best_stars_on_a_themed_tile_when_progress_has_them',
      () async {
    // Arrange: un temático ya jugado con 3★ (los temáticos puntúan como cualquiera).
    final entries = [
      CatalogEntry(id: LevelId('t-smiley'), section: LevelSection.themed),
    ];
    final progress = [
      LevelProgress(levelId: LevelId('t-smiley'), completed: true, bestStars: 3),
    ];
    final container = _containerWithEntries(entries, progress);
    // Act
    final view = await container.read(levelSelectionControllerProvider.future);
    // Assert
    expect(view.themedTiles.single.stars, 3);
    expect(view.themedTiles.single.locked, isFalse);
  });

  test('should_place_hex_section_entries_in_hexTiles_only', () async {
    // Arrange — catálogo mixto: 1 campaña, 1 temático, 1 hex.
    final entries = [
      CatalogEntry(id: LevelId('c1'), section: LevelSection.campaign),
      CatalogEntry(id: LevelId('t1'), section: LevelSection.themed),
      CatalogEntry(id: LevelId('h1'), section: LevelSection.hex),
    ];
    final container = _containerWithEntries(entries, const []);

    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);

    // Assert — la ficha hex vive SOLO en hexTiles: ni en campaña ni en temáticos.
    expect(view.hexTiles.map((t) => t.levelId), [LevelId('h1')]);
    expect(view.hexTiles.single.locked, isFalse);
    expect(view.hexTiles.single.position, 1);
    expect(view.themedTiles.map((t) => t.levelId), [LevelId('t1')]);
    expect(
      view.campaignTiers.expand((s) => s.tiles).map((t) => t.levelId),
      [LevelId('c1')],
    );
  });

  test('should_keep_a_themed_hex_level_in_themedTiles_not_hexTiles', () async {
    // Arrange — el temático hexagonal es section:themed (ADR-0007 D6), aunque
    // su ESPACIO sea hex: no aparece en el modo hex.
    final entries = [
      CatalogEntry(id: LevelId('t-hex'), section: LevelSection.themed),
    ];
    final container = _containerWithEntries(entries, const []);

    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);

    // Assert
    expect(view.themedTiles.map((t) => t.levelId), [LevelId('t-hex')]);
    expect(view.hexTiles, isEmpty);
  });

  test('should_leave_hexTiles_empty_when_catalog_has_no_hex_section', () async {
    // Arrange — catálogo clásico sin hex.
    final container = _containerWith(catalogIds, const []);

    // Act
    final view =
        await container.read(levelSelectionControllerProvider.future);

    // Assert — estado idéntico a antes: hexTiles vacío.
    expect(view.hexTiles, isEmpty);
  });
}
