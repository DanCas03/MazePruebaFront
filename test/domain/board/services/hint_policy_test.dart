import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/services/hint_policy.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';

// #102 — el auto-solver se abre a TODA la campaña (antes #32 lo restringía a
// número ≥ 7); los temáticos siguen elegibles vía el flag `themed`.
void main() {
  group('HintPolicy', () {
    const sut = HintPolicy();

    test('a campaign level that was previously below the #32 threshold is now eligible', () {
      // Arrange / Act / Assert — nivel 6 era inelegible bajo el umbral viejo.
      expect(sut.isEligible(LevelId('6')), isTrue);
    });

    test('a campaign level at or above the old threshold stays eligible', () {
      // Arrange / Act / Assert
      expect(sut.isEligible(LevelId('7')), isTrue);
      expect(sut.isEligible(LevelId('15')), isTrue);
    });

    test('the very first campaign level is eligible', () {
      // Arrange / Act / Assert — el piso de la campaña, antes siempre vetado.
      expect(sut.isEligible(LevelId('1')), isTrue);
    });

    test('a themed level is eligible regardless of its number', () {
      // Arrange — a themed id parses its number to the fallback 1.
      final themedId = LevelId('t-smiley');
      // Act / Assert
      expect(sut.isEligible(themedId, themed: true), isTrue);
      expect(sut.isEligible(themedId, themed: false), isTrue);
    });
  });
}
