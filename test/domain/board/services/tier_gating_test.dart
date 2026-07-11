import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_descriptor.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_test/flutter_test.dart';

LevelDescriptor d(String id, Tier t) =>
    LevelDescriptor(levelId: LevelId(id), tier: t);

LevelProgress done(String id) => LevelProgress(levelId: LevelId(id), completed: true);

void main() {
  const gating = TierGating();

  // Catálogo de 2 Tiers con 2 niveles cada uno.
  final catalog = [
    d('1', Tier.one),
    d('2', Tier.one),
    d('3', Tier.two),
    d('4', Tier.two),
  ];

  group('unlockedTiers', () {
    test('should_unlock_only_first_tier_when_there_is_no_progress', () {
      // Act
      final unlocked = gating.unlockedTiers(catalog, const []);
      // Assert
      expect(unlocked, {Tier.one});
    });

    test('should_keep_next_tier_locked_when_previous_tier_partially_completed',
        () {
      // Arrange: solo uno de los dos niveles del Tier 1 completado.
      final progress = [done('1')];
      // Act
      final unlocked = gating.unlockedTiers(catalog, progress);
      // Assert
      expect(unlocked, {Tier.one});
    });

    test('should_unlock_next_tier_when_all_previous_levels_completed', () {
      // Arrange: los dos niveles del Tier 1 completados.
      final progress = [done('1'), done('2')];
      // Act
      final unlocked = gating.unlockedTiers(catalog, progress);
      // Assert
      expect(unlocked, {Tier.one, Tier.two});
    });
  });

  group('isLevelUnlocked', () {
    test('should_report_level_locked_when_its_tier_is_locked', () {
      // Act & Assert: Tier 2 sigue bloqueado sin progreso.
      expect(
        gating.isLevelUnlocked(d('3', Tier.two), catalog, const []),
        isFalse,
      );
    });

    test('should_report_level_unlocked_when_its_tier_is_open', () {
      expect(
        gating.isLevelUnlocked(d('1', Tier.one), catalog, const []),
        isTrue,
      );
    });
  });
}
