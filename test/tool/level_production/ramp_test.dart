import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/value_objects/aspect_band.dart';

import '../../../tool/level_production/ramp.dart';

void main() {
  group('rampTable — estructura de la campaña (15 = 5 tiers × 3 + remate)', () {
    test('tiene seis escalones: T1–T5 regulares + el remate del T5', () {
      expect(rampTable.length, 6);
      expect(rampTable.where((s) => !s.finale).map((s) => s.tier),
          [1, 2, 3, 4, 5]);
      expect(rampTable.where((s) => s.finale).map((s) => s.tier), [5]);
    });

    test('dimensiones y densidad por escalón (tabla de la Rampa, banda 9:16)', () {
      RampStep t(int tier, {bool finale = false}) => rampStepFor(tier, finale: finale);

      expect((t(1).cols, t(1).rows, t(1).fillRatio, t(1).maxPathLen), (6, 10, 0.30, 3));
      expect((t(2).cols, t(2).rows, t(2).fillRatio, t(2).maxPathLen), (9, 16, 0.38, 5));
      expect((t(3).cols, t(3).rows, t(3).fillRatio, t(3).maxPathLen), (12, 22, 0.45, 7));
      expect((t(4).cols, t(4).rows, t(4).fillRatio, t(4).maxPathLen), (19, 34, 0.55, 10));
      expect((t(5).cols, t(5).rows, t(5).fillRatio, t(5).maxPathLen), (25, 44, 0.60, 12));
      final f = t(5, finale: true);
      expect((f.cols, f.rows, f.fillRatio, f.maxPathLen), (28, 50, 0.65, 12));
    });

    test('todos los tableros son verticales (cols <= rows), como el wire', () {
      for (final s in rampTable) {
        expect(s.cols, lessThanOrEqualTo(s.rows), reason: 'tier ${s.tier} finale=${s.finale}');
      }
    });

    test('every ramp step is inside the aspect band', () {
      for (final step in rampTable) {
        expect(AspectBand.contains(step.cols, step.rows), isTrue,
            reason: 'tier ${step.tier} ${step.cols}x${step.rows} out of band');
      }
    });
  });

  group('RampStep — derivaciones (arrowCount y timeLimitSec)', () {
    test('tiers 1–2 son sin límite; 3+ (y el remate) tienen límite derivado', () {
      expect(rampStepFor(1).timeLimitSec, isNull);
      expect(rampStepFor(2).timeLimitSec, isNull);
      expect(rampStepFor(3).timeLimitSec, isNotNull);
      expect(rampStepFor(4).timeLimitSec, isNotNull);
      expect(rampStepFor(5).timeLimitSec, isNotNull);
      expect(rampStepFor(5, finale: true).timeLimitSec, isNotNull);
    });

    test('arrowCount = celdas × fillRatio / avgPathLen, redondeado y acotado', () {
      // T1: 6×10=60, fill .30, avgPath=(2+3)/2=2.5 → 60*.30/2.5 = 7.2 → 7.
      expect(rampStepFor(1).arrowCount, 7);
      // T2: 9×16=144, fill .38, avgPath=(2+5)/2=3.5 → 144*.38/3.5 ≈ 15.63 → 16.
      expect(rampStepFor(2).arrowCount, 16);
      // T3: 12×22=264, fill .45, avgPath=(2+7)/2=4.5 → 264*.45/4.5 = 26.4 → 26.
      expect(rampStepFor(3).arrowCount, 26);
      // T4: 19×34=646, fill .55, avgPath=(2+10)/2=6 → 646*.55/6 ≈ 59.22 → 59.
      expect(rampStepFor(4).arrowCount, 59);
      // T5: 25×44=1100, fill .60, avgPath=(2+12)/2=7 → 1100*.60/7 ≈ 94.29 → 94.
      expect(rampStepFor(5).arrowCount, 94);
      // Remate 28×50=1400, fill .65, avgPath=(2+12)/2=7 → 1400*.65/7 = 130.
      expect(rampStepFor(5, finale: true).arrowCount, 130);
    });

    test('timeLimitSec = arrowCount×4 redondeado HACIA ARRIBA a múltiplo de 30', () {
      expect(rampStepFor(1).timeLimitSec, isNull);
      expect(rampStepFor(2).timeLimitSec, isNull);
      // T3: arrowCount 26 → 104 → 120 (múltiplo de 30 >= 104).
      expect(rampStepFor(3).timeLimitSec, 120);
      // T4: arrowCount 59 → 236 → 240.
      expect(rampStepFor(4).timeLimitSec, 240);
      // T5 regular: arrowCount 94 → 376 → 390.
      expect(rampStepFor(5).timeLimitSec, 390);
      // Remate: arrowCount 130 → 520 → 540.
      expect(rampStepFor(5, finale: true).timeLimitSec, 540);
    });

    test('todo timeLimitSec derivado es múltiplo exacto de 30', () {
      for (final s in rampTable) {
        final t = s.timeLimitSec;
        if (t != null) expect(t % 30, 0, reason: 'tier ${s.tier} finale=${s.finale}');
      }
    });
  });

  group('rampStepFor — validación de argumentos', () {
    test('rechaza tiers fuera de [1,5]', () {
      expect(() => rampStepFor(0), throwsArgumentError);
      expect(() => rampStepFor(6), throwsArgumentError);
    });

    test('solo el tier 5 admite remate', () {
      expect(() => rampStepFor(3, finale: true), throwsArgumentError);
      expect(rampStepFor(5, finale: true).finale, isTrue);
    });
  });
}
