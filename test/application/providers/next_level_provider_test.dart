import 'package:flutter_arrow_maze/application/providers/next_level_provider.dart';
import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';
import 'package:flutter_arrow_maze/domain/board/services/campaign_progression.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/level_selection_fakes.dart';

LevelProgress done(String id) =>
    LevelProgress(levelId: LevelId(id), completed: true);

/// Compone el provider con el Catálogo stubeado y un repo de progreso fake, y
/// resuelve el outcome para [current]. Espeja el cableado real: el provider lee
/// `levelCatalogProvider` y `levelProgressRepositoryProvider`.
Future<NextLevelOutcome> resolveWith({
  required List<LevelId> catalogIds,
  required List<LevelProgress> progress,
  required LevelId current,
}) async {
  final container = ProviderContainer(overrides: [
    stubCatalogOverride(ids: catalogIds),
    levelProgressRepositoryProvider
        .overrideWithValue(FakeLevelProgressRepository(progress)),
  ]);
  addTearDown(container.dispose);
  return container.read(nextLevelOutcomeProvider(current).future);
}

void main() {
  // 6 niveles ⇒ Tier.one = 1..3 ; Tier.two = 4..6.
  final ids = [for (var i = 1; i <= 6; i++) LevelId('$i')];

  group('nextLevelOutcomeProvider', () {
    test('should_lock_next_tier_when_last_of_tier_won_out_of_order', () async {
      // Arrange & Act: se gana el nivel 3 (último del Tier.one) sin 1 ni 2.
      final outcome =
          await resolveWith(catalogIds: ids, progress: const [], current: LevelId('3'));
      // Assert: bug #81 — el Tier.two sigue bloqueado ⇒ no se ofrece siguiente.
      expect(outcome, isA<NextLevelLocked>());
    });

    test('should_unlock_next_tier_when_previous_levels_completed', () async {
      // Arrange: 1 y 2 completados; se gana el 3.
      final outcome = await resolveWith(
        catalogIds: ids,
        progress: [done('1'), done('2')],
        current: LevelId('3'),
      );
      // Assert: Tier.two abre ⇒ el 4 es jugable.
      expect(outcome, isA<NextLevelUnlocked>());
      expect((outcome as NextLevelUnlocked).levelId, LevelId('4'));
    });

    test('should_offer_next_within_same_tier', () async {
      final outcome =
          await resolveWith(catalogIds: ids, progress: const [], current: LevelId('1'));
      expect(outcome, isA<NextLevelUnlocked>());
      expect((outcome as NextLevelUnlocked).levelId, LevelId('2'));
    });
  });
}
