import 'package:flutter_arrow_maze/domain/game_core/value_objects/strike_count.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StrikeCount', () {
    test('should_default_max_to_defaultMax_and_full_remaining_when_omitted', () {
      // Arrange & Act
      const strikes = StrikeCount(0);
      // Assert: sin max explícito usa el presupuesto por defecto (generados).
      expect(strikes.max, StrikeCount.defaultMax);
      expect(strikes.remaining, StrikeCount.defaultMax);
    });

    test('should_descend_remaining_by_one_per_strike', () {
      // Arrange: presupuesto de 3 errores.
      const strikes = StrikeCount(0, max: 3);
      // Act & Assert: el contador visible desciende 3 → 2 → 1 → 0.
      expect(strikes.remaining, 3);
      expect(strikes.increment().remaining, 2);
      expect(strikes.increment().increment().remaining, 1);
      expect(strikes.increment().increment().increment().remaining, 0);
    });

    test('should_preserve_max_across_increment', () {
      // Arrange
      const strikes = StrikeCount(0, max: 3);
      // Act
      final next = strikes.increment();
      // Assert: incrementar no pierde el presupuesto del nivel.
      expect(next.value, 1);
      expect(next.max, 3);
    });

    test('should_be_fatal_when_value_reaches_the_per_level_max', () {
      // Arrange & Act & Assert: fatal exactamente al agotar el presupuesto.
      expect(const StrikeCount(2, max: 3).isFatal, isFalse);
      expect(const StrikeCount(3, max: 3).isFatal, isTrue);
    });

    test('should_clamp_remaining_at_zero_and_never_go_negative', () {
      // Arrange & Act: más choques que el máximo (defensa).
      const strikes = StrikeCount(4, max: 3);
      // Assert
      expect(strikes.remaining, 0);
    });

    test('should_include_max_in_equality', () {
      // Arrange & Act & Assert: dos VOs con distinto presupuesto no son iguales.
      expect(const StrikeCount(0, max: 3), isNot(const StrikeCount(0, max: 5)));
      expect(const StrikeCount(1, max: 3), const StrikeCount(1, max: 3));
    });
  });
}
