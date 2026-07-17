import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/services/auto_solve_pacing.dart';

// #102 — el ritmo del auto-solver debe acelerar con el tamaño del tablero,
// sin que ningún paso empiece antes de que termine su animación de salida.
void main() {
  group('AutoSolvePacing.stepDelayFor', () {
    test('is strictly smaller for a high-arrow-count level than for a low-arrow-count level', () {
      // Arrange — T1 (~7 flechas) vs. un remate T5 (~180 flechas).
      final low = AutoSolvePacing.stepDelayFor(7);
      final high = AutoSolvePacing.stepDelayFor(180);
      // Act / Assert
      expect(high, lessThan(low));
    });

    test('is monotonically non-increasing across the whole curve', () {
      // Arrange — un barrido de conteos plausibles (por debajo, dentro y por
      // encima del rango de referencia de la rampa).
      const counts = [1, 4, 8, 15, 26, 50, 67, 90, 118, 120, 150, 180, 400];
      // Act
      final delays = counts.map(AutoSolvePacing.stepDelayFor).toList();
      // Assert — cada paso es <= al anterior; nunca sube al crecer el conteo.
      for (var i = 1; i < delays.length; i++) {
        expect(
          delays[i].inMilliseconds,
          lessThanOrEqualTo(delays[i - 1].inMilliseconds),
          reason: '${counts[i]} flechas debería demorar <= que ${counts[i - 1]}',
        );
      }
    });

    test('never drops below the exit-animation floor for that same count', () {
      // Arrange / Act / Assert — el piso documentado: el paso nunca puede
      // empezar antes de que termine la animación de salida vigente.
      for (final count in [1, 7, 8, 20, 60, 120, 121, 500]) {
        final delay = AutoSolvePacing.stepDelayFor(count).inMilliseconds;
        final floor = AutoSolvePacing.exitDurationFor(count).inMilliseconds;
        expect(delay, greaterThanOrEqualTo(floor),
            reason: 'delay de $count flechas cayó bajo su propio piso');
      }
    });

    test('small boards play at the deliberate ceiling (unchanged from #32)', () {
      // Arrange / Act / Assert — a partir de este conteo hacia abajo, la meseta
      // deliberada: mismo delay que el viejo hintStepDelay constante (420 ms).
      expect(AutoSolvePacing.stepDelayFor(1), const Duration(milliseconds: 420));
      expect(AutoSolvePacing.stepDelayFor(8), const Duration(milliseconds: 420));
    });

    test('very large boards play at the fast ceiling without dragging', () {
      // Arrange / Act / Assert — meseta rápida: no seguir acelerando indefinido.
      final atCeiling = AutoSolvePacing.stepDelayFor(120);
      final beyond = AutoSolvePacing.stepDelayFor(1000);
      expect(beyond, atCeiling);
      expect(atCeiling.inMilliseconds, lessThan(420));
    });
  });

  group('AutoSolvePacing.exitDurationFor', () {
    test('is the standard gameplay duration (360ms) for small boards', () {
      expect(AutoSolvePacing.exitDurationFor(8), const Duration(milliseconds: 360));
    });

    test('compresses for the largest boards, but not below a legible minimum', () {
      final compressed = AutoSolvePacing.exitDurationFor(1000);
      expect(compressed.inMilliseconds, lessThan(360));
      expect(compressed.inMilliseconds, greaterThanOrEqualTo(120));
    });

    test('is monotonically non-increasing in arrow count', () {
      const counts = [1, 8, 30, 60, 120, 300];
      final durations = counts.map(AutoSolvePacing.exitDurationFor).toList();
      for (var i = 1; i < durations.length; i++) {
        expect(durations[i].inMilliseconds,
            lessThanOrEqualTo(durations[i - 1].inMilliseconds));
      }
    });
  });
}
