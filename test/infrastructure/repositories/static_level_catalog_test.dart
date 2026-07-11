import 'package:flutter_arrow_maze/domain/board/value_objects/level_descriptor.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/static_level_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = StaticLevelCatalog();

  test('should_serve_fifteen_curated_levels', () async {
    // Act
    final levels = await catalog.getCatalog();
    // Assert
    expect(levels.length, 15);
  });

  test('should_group_three_levels_per_tier_across_five_tiers', () async {
    // Act
    final levels = await catalog.getCatalog();
    // Assert
    final byTier = <Tier, List<LevelDescriptor>>{};
    for (final l in levels) {
      byTier.putIfAbsent(l.tier, () => []).add(l);
    }
    expect(byTier.keys.toSet(), Tier.values.toSet());
    for (final tier in Tier.values) {
      expect(byTier[tier]!.length, 3, reason: 'Tier $tier should hold 3 levels');
    }
  });

  test('should_number_levels_one_based_and_in_order', () async {
    // Act
    final levels = await catalog.getCatalog();
    // Assert
    expect(levels.first.levelId.value, '1');
    expect(levels.last.levelId.value, '15');
    expect(levels[3].tier, Tier.two); // nivel 4 → Tier 2
  });
}
