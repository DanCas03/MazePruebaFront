import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';

void main() {
  GlobalLeaderboardEntry entry({
    String username = 'ana',
    int totalScore = 900,
    int totalStars = 12,
    int rank = 1,
  }) =>
      GlobalLeaderboardEntry(
        username: username,
        totalScore: totalScore,
        totalStars: totalStars,
        rank: rank,
      );

  group('GlobalLeaderboardEntry', () {
    test('should_throw_when_rank_below_one', () {
      // Arrange / Act / Assert
      expect(() => entry(rank: 0), throwsArgumentError);
    });

    test('should_throw_when_totals_negative', () {
      // Arrange / Act / Assert
      expect(() => entry(totalScore: -1), throwsArgumentError);
      expect(() => entry(totalStars: -1), throwsArgumentError);
    });

    test('should_equal_by_value', () {
      // Arrange / Act / Assert
      expect(entry(), entry());
      expect(entry(rank: 1), isNot(entry(rank: 2)));
    });
  });

  group('GlobalLeaderboard.meIsInTop', () {
    test('should_be_true_when_me_rank_within_top_length', () {
      // Arrange
      final board = GlobalLeaderboard(
        top: [entry(rank: 1), entry(username: 'leo', rank: 2)],
        me: entry(username: 'leo', rank: 2),
      );
      // Act / Assert
      expect(board.meIsInTop, isTrue);
    });

    test('should_be_false_when_me_rank_outside_top', () {
      // Arrange
      final board = GlobalLeaderboard(
        top: [entry(rank: 1)],
        me: entry(username: 'leo', rank: 42),
      );
      // Act / Assert
      expect(board.meIsInTop, isFalse);
    });

    test('should_be_false_when_me_is_null', () {
      // Arrange
      final board = GlobalLeaderboard(top: [entry(rank: 1)]);
      // Act / Assert
      expect(board.meIsInTop, isFalse);
    });

    test('should_expose_top_as_unmodifiable', () {
      // Arrange
      final board = GlobalLeaderboard(top: [entry(rank: 1)]);
      // Act / Assert
      expect(() => board.top.add(entry(rank: 2)), throwsUnsupportedError);
    });
  });
}
