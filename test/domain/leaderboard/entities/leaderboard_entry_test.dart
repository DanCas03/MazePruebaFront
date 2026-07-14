import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';

void main() {
  LeaderboardEntry entry({int timeSeconds = 45, String username = 'ana'}) =>
      LeaderboardEntry(
        id: 'abc-1',
        userId: 'user-7',
        username: username,
        levelId: LevelId('3'),
        score: Score(1200),
        stars: const Stars.three(),
        moves: const MoveCount(12),
        timeSeconds: timeSeconds,
        createdAt: DateTime.utc(2026, 7, 1, 10, 30),
      );

  group('LeaderboardEntry — construcción e invariantes', () {
    test('should_expose_wire_fields_when_constructed', () {
      // Arrange / Act
      final e = entry();
      // Assert
      expect(e.id, 'abc-1');
      expect(e.userId, 'user-7');
      expect(e.username, 'ana');
      expect(e.levelId.value, '3');
      expect(e.score.value, 1200);
      expect(e.stars.value, 3);
      expect(e.moves.value, 12);
      expect(e.timeSeconds, 45);
      expect(e.createdAt, DateTime.utc(2026, 7, 1, 10, 30));
    });

    test('should_throw_when_time_seconds_negative', () {
      // Arrange / Act / Assert
      expect(() => entry(timeSeconds: -1), throwsArgumentError);
    });
  });

  group('LeaderboardEntry — igualdad por valor', () {
    test('should_be_equal_when_all_fields_match', () {
      // Arrange / Act / Assert
      expect(entry(), entry());
    });

    test('should_differ_when_a_field_changes', () {
      // Arrange / Act / Assert
      expect(entry(timeSeconds: 45) == entry(timeSeconds: 46), isFalse);
    });

    test('should_differ_when_username_changes', () {
      // Arrange / Act / Assert
      expect(entry() == entry(username: 'other'), isFalse);
    });
  });
}
