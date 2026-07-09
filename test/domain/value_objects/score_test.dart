import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';

void main() {
  group('Score.fromRun — fórmula', () {
    test('should_return_base_when_instant_optimal_and_no_collisions', () {
      // Arrange / Act — partida perfecta: 0s, ruta óptima, sin choques
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 5,
        optimalMoves: 5,
        collisions: 0,
      );
      // Assert
      expect(score.value, Score.base);
    });

    test('should_subtract_time_penalty_per_second', () {
      // Arrange
      const seconds = 10;
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: seconds),
        moves: 5,
        optimalMoves: 5,
        collisions: 0,
      );
      // Assert
      expect(score.value, Score.base - seconds * Score.timePenaltyPerSecond);
    });

    test('should_subtract_extra_move_penalty_per_move_over_optimum', () {
      // Arrange — 3 movimientos por encima del óptimo
      const extra = 3;
      // Act
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 5 + extra,
        optimalMoves: 5,
        collisions: 0,
      );
      // Assert
      expect(score.value, Score.base - extra * Score.extraMovePenalty);
    });

    test('should_subtract_collision_penalty_per_collision', () {
      // Arrange
      const collisions = 2;
      // Act
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 5,
        optimalMoves: 5,
        collisions: collisions,
      );
      // Assert
      expect(score.value, Score.base - collisions * Score.collisionPenalty);
    });

    test('should_combine_all_penalties_deterministically', () {
      // Arrange
      const seconds = 4;
      const extra = 2;
      const collisions = 1;
      final expected = Score.base -
          seconds * Score.timePenaltyPerSecond -
          extra * Score.extraMovePenalty -
          collisions * Score.collisionPenalty;
      // Act
      final score = Score.fromRun(
        time: const Duration(seconds: seconds),
        moves: 5 + extra,
        optimalMoves: 5,
        collisions: collisions,
      );
      // Assert
      expect(score.value, expected);
    });

    test('should_clamp_to_zero_when_penalties_exceed_base', () {
      // Arrange — tiempo enorme que superaría la base
      // Act
      final score = Score.fromRun(
        time: const Duration(hours: 1),
        moves: 5,
        optimalMoves: 5,
        collisions: 0,
      );
      // Assert
      expect(score.value, 0);
    });

    test('should_ignore_moves_below_optimum_when_scoring', () {
      // Arrange — menos movimientos que el óptimo no otorga bonus sobre la base
      // Act
      final score = Score.fromRun(
        time: Duration.zero,
        moves: 3,
        optimalMoves: 5,
        collisions: 0,
      );
      // Assert
      expect(score.value, Score.base);
    });
  });

  group('Score — invariantes', () {
    test('should_reject_negative_value', () {
      // Arrange / Act / Assert
      expect(() => Score(-1), throwsA(isA<AssertionError>()));
    });

    test('should_be_equal_when_same_value', () {
      // Arrange / Act / Assert
      expect(const Score(100), const Score(100));
    });
  });
}
