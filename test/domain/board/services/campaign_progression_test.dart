import 'package:flutter_arrow_maze/domain/board/services/campaign_progression.dart';
import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogEntry campaign(String id) =>
    CatalogEntry(id: LevelId(id), section: LevelSection.campaign);

CatalogEntry themed(String id) =>
    CatalogEntry(id: LevelId(id), section: LevelSection.themed);

LevelProgress done(String id) =>
    LevelProgress(levelId: LevelId(id), completed: true);

void main() {
  const progression = CampaignProgression(TierGating());

  // 6 niveles de campaña ⇒ Tier.one = 1,2,3 ; Tier.two = 4,5,6 (3 por Tier).
  final catalog = [
    campaign('1'),
    campaign('2'),
    campaign('3'),
    campaign('4'),
    campaign('5'),
    campaign('6'),
  ];

  group('CampaignProgression.resolve', () {
    test('should_offer_next_level_within_the_same_unlocked_tier', () {
      // Arrange: nivel 1 (Tier.one, siempre abierto), sin progreso previo.
      // Act
      final outcome = progression.resolve(LevelId('1'), catalog, const []);
      // Assert: el siguiente (nivel 2) es del mismo Tier abierto ⇒ jugable.
      expect(outcome, isA<NextLevelUnlocked>());
      expect((outcome as NextLevelUnlocked).levelId, LevelId('2'));
    });

    test(
        'should_lock_next_tier_when_crossing_boundary_with_previous_levels_incomplete',
        () {
      // Arrange: se gana el ÚLTIMO del Tier.one (nivel 3) SIN haber completado
      // los niveles 1 y 2 (entrada fuera de orden dentro del Tier abierto). El
      // siguiente (nivel 4) es del Tier.two, que sigue bloqueado.
      // Act: el nivel actual (3) se cuenta como recién completado.
      final outcome = progression.resolve(LevelId('3'), catalog, const []);
      // Assert: NO se ofrece el siguiente Tier bloqueado (regresión del bug #81).
      expect(outcome, isA<NextLevelLocked>());
    });

    test('should_unlock_next_tier_when_all_previous_levels_completed', () {
      // Arrange: niveles 1 y 2 completados; se gana el 3 (último del Tier.one).
      // Con el 3 recién ganado, TODO el Tier.one queda completo ⇒ Tier.two abre.
      final progress = [done('1'), done('2')];
      // Act
      final outcome = progression.resolve(LevelId('3'), catalog, progress);
      // Assert: el siguiente (nivel 4) ya es jugable.
      expect(outcome, isA<NextLevelUnlocked>());
      expect((outcome as NextLevelUnlocked).levelId, LevelId('4'));
    });

    test('should_report_campaign_complete_on_the_last_campaign_level', () {
      // Arrange & Act: nivel 6, el último del catálogo de campaña.
      final outcome = progression.resolve(LevelId('6'), catalog, const []);
      // Assert
      expect(outcome, isA<CampaignComplete>());
    });

    test('should_report_not_in_campaign_for_a_themed_level', () {
      // Arrange: un temático intercalado que no pertenece a la campaña.
      final mixed = [campaign('1'), themed('t-heart'), campaign('2')];
      // Act
      final outcome = progression.resolve(LevelId('t-heart'), mixed, const []);
      // Assert: los temáticos no tienen adyacencia de "siguiente nivel".
      expect(outcome, isA<NotInCampaign>());
    });

    test('should_skip_interleaved_themed_when_choosing_the_next_campaign_level',
        () {
      // Arrange: temático intercalado entre dos niveles de campaña; el Tier se
      // deriva de la POSICIÓN entre los de campaña, así que 1→2 sigue en Tier.one.
      final mixed = [campaign('1'), themed('t-heart'), campaign('2')];
      // Act
      final outcome = progression.resolve(LevelId('1'), mixed, const []);
      // Assert: el siguiente de campaña es el 2, saltando el temático.
      expect(outcome, isA<NextLevelUnlocked>());
      expect((outcome as NextLevelUnlocked).levelId, LevelId('2'));
    });
  });
}
