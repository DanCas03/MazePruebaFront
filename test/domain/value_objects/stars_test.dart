import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';

void main() {
  group('Stars.rate — umbrales', () {
    test('should_award_three_stars_when_no_collisions_and_moves_at_optimum', () {
      // Arrange / Act
      final stars = Stars.rate(moves: 5, optimalMoves: 5, collisions: 0);
      // Assert
      expect(stars.value, 3);
    });

    test('should_award_three_stars_when_extra_moves_within_tolerance_and_no_collisions', () {
      // Arrange — óptimo + k exacto
      final moves = 5 + Stars.perfectMoveTolerance;
      // Act
      final stars = Stars.rate(moves: moves, optimalMoves: 5, collisions: 0);
      // Assert
      expect(stars.value, 3);
    });

    test('should_not_award_three_stars_when_there_is_any_collision', () {
      // Arrange — ruta óptima pero con un choque
      // Act
      final stars = Stars.rate(moves: 5, optimalMoves: 5, collisions: 1);
      // Assert
      expect(stars.value, lessThan(3));
    });

    test('should_award_two_stars_when_extra_moves_exceed_tolerance_but_within_two_star_bounds', () {
      // Arrange — óptimo + (k + 1): pierde la 3ª estrella pero conserva la 2ª
      final moves = 5 + Stars.perfectMoveTolerance + 1;
      // Act
      final stars = Stars.rate(moves: moves, optimalMoves: 5, collisions: 0);
      // Assert
      expect(stars.value, 2);
    });

    test('should_award_two_stars_when_collisions_within_two_star_bound', () {
      // Arrange
      // Act
      final stars = Stars.rate(
        moves: 5,
        optimalMoves: 5,
        collisions: Stars.twoStarMaxCollisions,
      );
      // Assert
      expect(stars.value, 2);
    });

    test('should_award_one_star_when_collisions_exceed_two_star_bound', () {
      // Arrange
      final collisions = Stars.twoStarMaxCollisions + 1;
      // Act
      final stars = Stars.rate(moves: 5, optimalMoves: 5, collisions: collisions);
      // Assert
      expect(stars.value, 1);
    });

    test('should_award_one_star_when_moves_far_above_optimum', () {
      // Arrange — muy por encima de la cota de 2★
      final moves = 5 + Stars.twoStarMoveTolerance + 1;
      // Act
      final stars = Stars.rate(moves: moves, optimalMoves: 5, collisions: 0);
      // Assert
      expect(stars.value, 1);
    });

    test('should_ignore_moves_below_optimum_when_rating', () {
      // Arrange — menos movimientos que el óptimo no penaliza (exceso acotado a 0)
      // Act
      final stars = Stars.rate(moves: 3, optimalMoves: 5, collisions: 0);
      // Assert
      expect(stars.value, 3);
    });
  });

  group('Stars — igualdad por valor', () {
    test('should_be_equal_when_same_value', () {
      // Arrange / Act / Assert
      expect(const Stars.three(), Stars.rate(moves: 5, optimalMoves: 5, collisions: 0));
    });
  });
}
