import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';

// Score.fromRun — fórmula multiplicativa PREVIEW (espeja al back):
//   round(10000 × (optimal / max(moves, optimal))² × 0.8^collisions
//         × 2^(−seconds / par))
//   par = timeLimitSec / 2   (o `optimal × 3` si timeLimitSec es null —
//   nivel legado en caché / tablero sin límite)
//   piso 100; optimal se acota a ≥1; moves a ≥optimal (por debajo del óptimo
//   no da crédito extra); collisions/segundos se acotan a ≥0.
void main() {
  group('Score.fromRun — fórmula multiplicativa', () {
    test('should_return_10000_when_instant_optimal_and_no_collisions', () {
      // Arrange / Act — partida perfecta: 0s, ruta óptima, sin choques
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 5,
        optimalMoves: 5,
        collisions: 0,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, 10000);
    });

    test('should_return_5000_when_time_equals_par', () {
      // Arrange — par = timeLimitSec / 2 = 60s; resto perfecto
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: 60),
        moves: 5,
        optimalMoves: 5,
        collisions: 0,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, 5000);
    });

    test('should_return_2500_when_time_equals_time_limit', () {
      // Arrange — time = timeLimitSec completo (2 pares); resto perfecto
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: 120),
        moves: 5,
        optimalMoves: 5,
        collisions: 0,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, 2500);
    });

    test('should_return_2500_when_moves_double_optimal', () {
      // Arrange — moves = 2×optimal, ratio² = 0.25; resto perfecto
      // Act
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 10,
        optimalMoves: 5,
        collisions: 0,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, 2500);
    });

    test('should_return_8000_when_one_collision', () {
      // Arrange — 0.8^1 = 0.8; resto perfecto
      // Act
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 5,
        optimalMoves: 5,
        collisions: 1,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, 8000);
    });

    test('should_ignore_moves_below_optimum_when_scoring', () {
      // Arrange — menos movimientos que el óptimo no otorga bonus: se acota a
      // optimalMoves, igual que el caso moves == optimalMoves.
      // Act
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 3,
        optimalMoves: 5,
        collisions: 0,
        timeLimitSec: 120,
      );
      // Assert — idéntico al caso perfecto (moves == optimal)
      expect(score.value, 10000);
    });

    test('should_floor_at_100_on_extreme_run', () {
      // Arrange — corrida extrema: 10× movimientos del óptimo, 10 choques,
      // 5× el timeLimit transcurrido. El valor crudo cae muy por debajo de
      // 100 (~0.01) y debe acotarse al piso, NUNCA a 0.
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: 600),
        moves: 100,
        optimalMoves: 10,
        collisions: 10,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, 100);
    });

    test('should_use_optimal_times_3_seconds_as_par_when_time_limit_is_null',
        () {
      // Arrange — nivel sin límite de tiempo (legado en caché): par =
      // optimal × 3 = 30s. time = par, resto perfecto ⇒ mismo resultado que
      // el caso "time == par" con límite explícito.
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: 30),
        moves: 10,
        optimalMoves: 10,
        collisions: 0,
        timeLimitSec: null,
      );
      // Assert
      expect(score.value, 5000);
    });

    test('should_always_return_integer_in_100_to_10000_range', () {
      // Arrange — corrida arbitraria intermedia, ni perfecta ni extrema
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: 45),
        moves: 8,
        optimalMoves: 5,
        collisions: 2,
        timeLimitSec: 120,
      );
      // Assert
      expect(score.value, greaterThanOrEqualTo(100));
      expect(score.value, lessThanOrEqualTo(10000));
      expect(score.value, isA<int>());
    });
  });

  group('Score — invariantes', () {
    test('should_reject_negative_value', () {
      // Arrange / Act / Assert — invariante en runtime (vale también en release)
      expect(() => Score(-1), throwsArgumentError);
    });

    test('should_be_equal_when_same_value', () {
      // Arrange / Act / Assert
      expect(Score(100), Score(100));
    });
  });
}
