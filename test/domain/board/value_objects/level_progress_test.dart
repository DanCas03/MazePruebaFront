import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';

void main() {
  group('LevelProgress', () {
    test('should_hold_fields_when_constructed_with_valid_values', () {
      // Arrange / Act
      final p = LevelProgress(
          levelId: LevelId('1'), completed: true, bestScore: 1200, bestStars: 3);
      // Assert
      expect(p.levelId, LevelId('1'));
      expect(p.completed, isTrue);
      expect(p.bestScore, 1200);
      expect(p.bestStars, 3);
    });

    test('should_allow_null_score_and_stars_when_level_completed_without_score', () {
      // Arrange / Act
      final p = LevelProgress(levelId: LevelId('2'), completed: true);
      // Assert
      expect(p.bestScore, isNull);
      expect(p.bestStars, isNull);
    });

    test('should_be_value_equal_when_all_fields_match', () {
      // Arrange / Act
      final a = LevelProgress(levelId: LevelId('1'), completed: false, bestScore: 0);
      final b = LevelProgress(levelId: LevelId('1'), completed: false, bestScore: 0);
      // Assert
      expect(a, equals(b));
    });

    test('should_throw_when_bestScore_is_negative', () {
      // Arrange / Act / Assert
      expect(
        () => LevelProgress(levelId: LevelId('1'), completed: true, bestScore: -1),
        throwsArgumentError,
      );
    });

    test('should_throw_when_bestStars_out_of_range', () {
      // Arrange / Act / Assert
      expect(
        () => LevelProgress(levelId: LevelId('1'), completed: true, bestStars: 4),
        throwsArgumentError,
      );
    });
  });
}
