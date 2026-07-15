import 'package:flutter_test/flutter_test.dart';

import '../../../tool/level_production/ramp.dart';

void main() {
  group('rampTable — estructura de la campaña (15 = 5 tiers × 3 + remate)', () {
    test('tiene seis escalones: T1–T5 regulares + el remate del T5', () {
      expect(rampTable.length, 6);
      expect(rampTable.where((s) => !s.finale).map((s) => s.tier),
          [1, 2, 3, 4, 5]);
      expect(rampTable.where((s) => s.finale).map((s) => s.tier), [5]);
    });

    test('dimensiones y densidad por escalón (tabla de la Rampa)', () {
      RampStep t(int tier, {bool finale = false}) => rampStepFor(tier, finale: finale);

      expect((t(1).cols, t(1).rows, t(1).fillRatio, t(1).maxPathLen), (6, 8, 0.30, 3));
      expect((t(2).cols, t(2).rows, t(2).fillRatio, t(2).maxPathLen), (10, 12, 0.38, 5));
      expect((t(3).cols, t(3).rows, t(3).fillRatio, t(3).maxPathLen), (18, 20, 0.45, 7));
      expect((t(4).cols, t(4).rows, t(4).fillRatio, t(4).maxPathLen), (30, 34, 0.55, 10));
      expect((t(5).cols, t(5).rows, t(5).fillRatio, t(5).maxPathLen), (42, 46, 0.60, 12));
      final f = t(5, finale: true);
      expect((f.cols, f.rows, f.fillRatio, f.maxPathLen), (50, 50, 0.65, 12));
    });

    test('todos los tableros son verticales (cols <= rows), como el wire', () {
      for (final s in rampTable) {
        expect(s.cols, lessThanOrEqualTo(s.rows), reason: 'tier ${s.tier} finale=${s.finale}');
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
      // T3: 18×20=360, fill .45, avgPath=(2+7)/2=4.5 → 360*.45/4.5 = 36.
      expect(rampStepFor(3).arrowCount, 36);
      // Remate 50×50=2500, fill .65, avgPath=(2+12)/2=7 → 2500*.65/7 ≈ 232.
      expect(rampStepFor(5, finale: true).arrowCount, 232);
    });

    test('timeLimitSec = arrowCount×4 redondeado HACIA ARRIBA a múltiplo de 30', () {
      // T3: arrowCount 36 → 144 → 150 (múltiplo de 30 >= 144).
      expect(rampStepFor(3).timeLimitSec, 150);
      // Remate: arrowCount 232 → 928 → 930.
      expect(rampStepFor(5, finale: true).timeLimitSec, 930);
      // T5 regular: 42×46=1932, fill .60, avgPath 7 → 166 → 664 → 690.
      expect(rampStepFor(5).arrowCount, 166);
      expect(rampStepFor(5).timeLimitSec, 690);
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
