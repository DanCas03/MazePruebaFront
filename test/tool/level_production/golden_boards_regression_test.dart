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
///
/// back#46 (reshape 9:16, all-timed): representantes re-congelados sobre la
/// rampa final — orden 1 de la campaña (cand-t1-s104, 6×10) y orden 15/remate
/// (cand-t5-s924, 28×50). Reemplazan a cand-t1-s101 (6×8, pre-reshape) y
/// cand-t5-s918 (50×50, pre-reshape).
void main() {
  group('golden boards — regresión 9:16 all-timed (back#46)', () {
    test('tier 1, seed 104 (6x10) se mantiene byte-idéntico', () {
      // Arrange
      final spec = CandidateSpec(step: rampStepFor(1), seed: 104);
      final golden =
          File('test/fixtures/golden_boards/cand-t1-s104.json').readAsStringSync();

      // Act
      final result = produceCandidate(spec);

      // Assert
      expect(result.json, golden);
    });

    test('tier 5 finale, seed 924 (28x50) se mantiene byte-idéntico', () {
      // Arrange
      final spec = CandidateSpec(step: rampStepFor(5, finale: true), seed: 924);
      final golden =
          File('test/fixtures/golden_boards/cand-t5-s924.json').readAsStringSync();

      // Act
      final result = produceCandidate(spec);

      // Assert
      expect(result.json, golden);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
