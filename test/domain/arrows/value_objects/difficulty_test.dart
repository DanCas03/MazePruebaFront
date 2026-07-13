import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';

void main() {
  group('Difficulty — presets documentados (front#36)', () {
    test('should_map_each_preset_to_documented_constants', () {
      // Assert — estas constantes son contrato documentado (README front#36):
      // densidad de flechas, largo máximo de camino y segundos por celda.
      expect(Difficulty.easy.fillRatio, 0.40);
      expect(Difficulty.easy.maxPathLen, 3);
      expect(Difficulty.easy.secondsPerCell, 3.0);

      expect(Difficulty.medium.fillRatio, 0.55);
      expect(Difficulty.medium.maxPathLen, 6);
      expect(Difficulty.medium.secondsPerCell, 2.0);

      expect(Difficulty.hard.fillRatio, 0.70);
      expect(Difficulty.hard.maxPathLen, 9);
      expect(Difficulty.hard.secondsPerCell, 1.5);
    });

    test('should_scale_monotonically_with_difficulty', () {
      // Assert — más difícil ⇒ más densidad, caminos más largos y menos
      // tiempo por celda; si un preset rompe la monotonía es un bug de curva.
      expect(Difficulty.easy.fillRatio, lessThan(Difficulty.medium.fillRatio));
      expect(Difficulty.medium.fillRatio, lessThan(Difficulty.hard.fillRatio));

      expect(Difficulty.easy.maxPathLen, lessThan(Difficulty.medium.maxPathLen));
      expect(Difficulty.medium.maxPathLen, lessThan(Difficulty.hard.maxPathLen));

      expect(
        Difficulty.easy.secondsPerCell,
        greaterThan(Difficulty.medium.secondsPerCell),
      );
      expect(
        Difficulty.medium.secondsPerCell,
        greaterThan(Difficulty.hard.secondsPerCell),
      );
    });
  });
}
