import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tier.forLevelNumber', () {
    test('should_map_first_three_levels_to_tier_one_when_within_first_group',
        () {
      // Assert
      expect(Tier.forLevelNumber(1), Tier.one);
      expect(Tier.forLevelNumber(2), Tier.one);
      expect(Tier.forLevelNumber(3), Tier.one);
    });

    test('should_map_levels_four_to_six_to_tier_two_when_within_second_group',
        () {
      expect(Tier.forLevelNumber(4), Tier.two);
      expect(Tier.forLevelNumber(6), Tier.two);
    });

    test('should_saturate_to_last_tier_when_number_exceeds_ramp', () {
      expect(Tier.forLevelNumber(16), Tier.five);
      expect(Tier.forLevelNumber(100), Tier.five);
    });

    test('should_clamp_to_tier_one_when_number_is_non_positive', () {
      expect(Tier.forLevelNumber(0), Tier.one);
      expect(Tier.forLevelNumber(-5), Tier.one);
    });
  });

  group('Tier navigation', () {
    test('should_expose_one_based_rank', () {
      expect(Tier.one.rank, 1);
      expect(Tier.five.rank, 5);
    });

    test('should_return_null_previous_when_first_tier', () {
      expect(Tier.one.previous, isNull);
    });

    test('should_return_preceding_tier_as_previous_when_not_first', () {
      expect(Tier.three.previous, Tier.two);
    });
  });
}
