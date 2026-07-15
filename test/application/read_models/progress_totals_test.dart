import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/read_models/progress_totals.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';

void main() {
  LevelProgress lp(String id, {required bool completed, int? stars}) =>
      LevelProgress(
        levelId: LevelId(id),
        completed: completed,
        bestStars: stars,
      );

  group('ProgressTotals.from', () {
    test('an empty progress list yields zero totals', () {
      // Act
      final totals = ProgressTotals.from([]);
      // Assert
      expect(totals.totalStars, 0);
      expect(totals.completedLevels, 0);
    });

    test('sums bestStars and counts completed levels', () {
      // Arrange
      final progress = [
        lp('l1', completed: true, stars: 3),
        lp('l2', completed: true, stars: 1),
        lp('l3', completed: false, stars: 2), // jugado con estrellas, no completado
        lp('l4', completed: false), // ni estrellas ni completado
      ];
      // Act
      final totals = ProgressTotals.from(progress);
      // Assert
      expect(totals.totalStars, 6); // 3 + 1 + 2 + 0
      expect(totals.completedLevels, 2); // l1, l2
    });

    test('treats a null bestStars as zero (completed counts regardless)', () {
      // Arrange
      final progress = [lp('l1', completed: true)];
      // Act
      final totals = ProgressTotals.from(progress);
      // Assert
      expect(totals.totalStars, 0);
      expect(totals.completedLevels, 1);
    });
  });
}
