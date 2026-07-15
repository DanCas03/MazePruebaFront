import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/services/hint_policy.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';

// front#67 — la elegibilidad de la pista es consciente de sección: la campaña
// mantiene el umbral por número (>= 7); los temáticos son siempre elegibles vía
// el flag `themed`, sin depender del parseo numérico del id (`t-…` → 1).
void main() {
  group('HintPolicy', () {
    const sut = HintPolicy();

    test('campaign level below the threshold is not eligible', () {
      // Arrange / Act / Assert
      expect(sut.isEligible(LevelId('6')), isFalse);
    });

    test('campaign level at or above the threshold is eligible', () {
      // Arrange / Act / Assert
      expect(sut.isEligible(LevelId('7')), isTrue);
      expect(sut.isEligible(LevelId('15')), isTrue);
    });

    test('themed level is always eligible regardless of its number', () {
      // Arrange — a themed id parses its number to the fallback 1 (< threshold).
      final themedId = LevelId('t-smiley');
      // Act / Assert — the themed flag makes it eligible despite number == 1.
      expect(sut.isEligible(themedId, themed: true), isTrue);
    });

    test('same themed id is NOT eligible when treated as campaign', () {
      // Arrange — proves the flag, not the id, drives themed eligibility: the
      // `t-…` number-fallback wart would otherwise silently exclude it.
      final themedId = LevelId('t-smiley');
      // Act / Assert
      expect(sut.isEligible(themedId, themed: false), isFalse);
    });
  });
}
