// test/tool/level_production/golden_boards_regression_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/level_production/candidate_producer.dart';
import '../../../tool/level_production/ramp.dart';

/// Fija el output del generador para (tier, seed) ANTES del refactor
/// BoardSpace (front#73, ADR-0005). El generador debe seguir produciendo
/// exactamente el mismo JSON durante todo el refactor — mismo seed, misma
/// secuencia de llamadas a Random, mismo tablero. Si este test rompe en
/// cualquier tarea posterior, el refactor tiene un bug de reproducibilidad:
/// NO se recaptura el golden, se corrige el código.
void main() {
  group('golden boards — regresión pre-BoardSpace (front#73)', () {
    test('tier 1, seed 101 (6x8) se mantiene byte-idéntico', () {
      // Arrange
      final spec = CandidateSpec(step: rampStepFor(1), seed: 101);
      final golden =
          File('test/fixtures/golden_boards/cand-t1-s101.json').readAsStringSync();

      // Act
      final result = produceCandidate(spec);

      // Assert
      expect(result.json, golden);
    });

    test('tier 5 finale, seed 918 (50x50) se mantiene byte-idéntico', () {
      // Arrange
      final spec = CandidateSpec(step: rampStepFor(5, finale: true), seed: 918);
      final golden =
          File('test/fixtures/golden_boards/cand-t5-s918.json').readAsStringSync();

      // Act
      final result = produceCandidate(spec);

      // Assert
      expect(result.json, golden);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
