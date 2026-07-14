import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/get_leaderboard_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';

import 'get_leaderboard_use_case_test.mocks.dart';

@GenerateMocks([ILeaderboardRepository, ILoggerService])
void main() {
  late MockILeaderboardRepository repository;
  late MockILoggerService logger;
  late GetLeaderboardUseCase useCase;

  setUp(() {
    repository = MockILeaderboardRepository();
    logger = MockILoggerService();
    useCase = GetLeaderboardUseCase(repository, logger);
  });

  LeaderboardEntry entryRow() => LeaderboardEntry(
        id: 'row-1',
        userId: 'user-1',
        username: 'ana',
        levelId: LevelId('7'),
        score: Score(1200),
        stars: const Stars.three(),
        moves: const MoveCount(12),
        timeSeconds: 45,
        createdAt: DateTime.utc(2026, 7, 1, 10, 30),
      );

  test('should_return_entries_and_log_when_repository_succeeds', () async {
    // Arrange
    when(repository.getLeaderboard(any, limit: anyNamed('limit')))
        .thenAnswer((_) async => [entryRow()]);
    // Act
    final result = await useCase.execute(LevelId('7'));
    // Assert
    expect(result, hasLength(1));
    expect(result.single.id, 'row-1');
    verify(logger.log(any, 'GetLeaderboardUseCase')).called(1);
  });

  test('should_forward_limit_to_repository', () async {
    // Arrange
    when(repository.getLeaderboard(any, limit: anyNamed('limit')))
        .thenAnswer((_) async => const []);
    // Act
    await useCase.execute(LevelId('7'), limit: 5);
    // Assert
    verify(repository.getLeaderboard(LevelId('7'), limit: 5)).called(1);
  });

  test('should_rethrow_and_log_error_when_repository_fails', () async {
    // Arrange
    when(repository.getLeaderboard(any, limit: anyNamed('limit')))
        .thenThrow(Exception('red caída'));
    // Act / Assert — propaga para que la UI muestre estado de error
    await expectLater(() => useCase.execute(LevelId('7')), throwsException);
    verify(logger.error(any, 'GetLeaderboardUseCase', any)).called(1);
  });
}
