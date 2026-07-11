import 'package:flutter_arrow_maze/application/state/level_selection_controller.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_descriptor.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/level_selection_fakes.dart';

ProviderContainer _containerWith(
  List<LevelDescriptor> catalog,
  List<LevelProgress> progress,
) {
  final container = ProviderContainer(
    overrides: [levelSelectionOverride(catalog: catalog, progress: progress)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final catalog = [
    levelDescriptor('1', Tier.one),
    levelDescriptor('2', Tier.one),
    levelDescriptor('3', Tier.one),
    levelDescriptor('4', Tier.two),
    levelDescriptor('5', Tier.two),
    levelDescriptor('6', Tier.two),
  ];

  test('should_group_tiles_into_sections_by_tier_when_built', () async {
    // Arrange
    final container = _containerWith(catalog, const []);
    // Act
    final sections =
        await container.read(levelSelectionControllerProvider.future);
    // Assert
    expect(sections.length, 2);
    expect(sections[0].tier, Tier.one);
    expect(sections[0].tiles.length, 3);
    expect(sections[1].tier, Tier.two);
  });

  test('should_expose_best_stars_when_progress_has_them', () async {
    // Arrange
    final progress = [
      LevelProgress(levelId: LevelId('1'), completed: true, bestStars: 2),
    ];
    final container = _containerWith(catalog, progress);
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
    final container = _containerWith(catalog, progress);
    // Act
    final sections =
        await container.read(levelSelectionControllerProvider.future);
    // Assert
    final tile1 = sections[0].tiles.firstWhere((t) => t.levelId.value == '1');
    expect(tile1.stars, 0);
  });

  test('should_lock_second_tier_when_first_tier_incomplete', () async {
    // Arrange
    final container = _containerWith(catalog, const []);
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
    final container = _containerWith(catalog, progress);
    // Act
    final sections =
        await container.read(levelSelectionControllerProvider.future);
    // Assert
    expect(sections[1].tiles.every((t) => !t.locked), isTrue);
  });
}
