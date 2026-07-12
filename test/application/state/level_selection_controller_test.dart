import 'package:flutter_arrow_maze/application/providers/level_catalog_provider.dart';
import 'package:flutter_arrow_maze/application/state/level_selection_controller.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
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

void main() {
  // Catálogo remoto de 6 ids: por POSICIÓN, 1-3 → Tier.one y 4-6 → Tier.two.
  final catalogIds = [for (var n = 1; n <= 6; n++) LevelId('$n')];

  test('should_group_tiles_into_sections_by_tier_when_built', () async {
    // Arrange
    final container = _containerWith(catalogIds, const []);
    // Act
    final sections =
        await container.read(levelSelectionControllerProvider.future);
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
    final sections =
        await container.read(levelSelectionControllerProvider.future);
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
    final sections =
        await container.read(levelSelectionControllerProvider.future);
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
    final sections =
        await container.read(levelSelectionControllerProvider.future);
    // Assert
    final tile1 = sections[0].tiles.firstWhere((t) => t.levelId.value == '1');
    expect(tile1.stars, 0);
  });

  test('should_lock_second_tier_when_first_tier_incomplete', () async {
    // Arrange
    final container = _containerWith(catalogIds, const []);
    // Act
    final sections =
        await container.read(levelSelectionControllerProvider.future);
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
    final sections =
        await container.read(levelSelectionControllerProvider.future);
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
}
