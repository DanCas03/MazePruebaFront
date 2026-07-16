// test/tool/level_production/golden_boards_regression_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/level_production/candidate_producer.dart';
import '../../../tool/level_production/ramp.dart';

/// Forward regression guard (patrón back#39): fija el output del generador
/// por bandas (spec 2026-07-15-generator-band-density-design.md) para
/// (tier, seed). Si rompe SIN un cambio deliberado del generador, hay un bug
/// de reproducibilidad. Ante un cambio deliberado, recapturar con un script
/// puntual que escriba produceCandidate(spec).json en test/fixtures/.
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
