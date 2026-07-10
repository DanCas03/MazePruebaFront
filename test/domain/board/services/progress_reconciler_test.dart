import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/services/progress_reconciler.dart';

LevelProgress lp(String id, bool completed, {int? score, int? stars}) =>
    LevelProgress(levelId: LevelId(id), completed: completed, bestScore: score, bestStars: stars);

LevelProgress pick(List<LevelProgress> list, String id) =>
    list.firstWhere((p) => p.levelId.value == id);

void main() {
  late ProgressReconciler reconciler;
  setUp(() => reconciler = ProgressReconciler());

  group('reconcile', () {
    test('should_keep_higher_score_when_both_sides_have_score', () {
      // Arrange
      final local = [lp('1', true, score: 800, stars: 2)];
      final remote = [lp('1', true, score: 1200, stars: 3)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(pick(merged, '1').bestScore, 1200);
      expect(pick(merged, '1').bestStars, 3);
    });

    test('should_prefer_non_null_score_when_one_side_is_null', () {
      // Arrange
      final local = [lp('1', true)]; // no score
      final remote = [lp('1', true, score: 500, stars: 1)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(pick(merged, '1').bestScore, 500);
      expect(pick(merged, '1').bestStars, 1);
    });

    test('should_mark_completed_when_completed_on_either_side', () {
      // Arrange
      final local = [lp('1', false)];
      final remote = [lp('1', true)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(pick(merged, '1').completed, isTrue);
    });

    test('should_include_levels_present_on_only_one_side', () {
      // Arrange
      final local = [lp('1', true, score: 100)];
      final remote = [lp('2', true, score: 200)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(merged.length, 2);
      expect(pick(merged, '1').bestScore, 100);
      expect(pick(merged, '2').bestScore, 200);
    });
  });
}
