import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/submit_score_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/repositories/i_leaderboard_repository.dart';

import 'submit_score_use_case_test.mocks.dart';

@GenerateMocks([ILeaderboardRepository, ILoggerService])
void main() {
  late MockILeaderboardRepository repository;
  late MockILoggerService logger;
  late SubmitScoreUseCase useCase;

  setUp(() {
    repository = MockILeaderboardRepository();
    logger = MockILoggerService();
    useCase = SubmitScoreUseCase(repository, logger);
  });

  ScoreEntry entry() => ScoreEntry(
        levelId: LevelId('7'),
        score: Score(1200),
        stars: const Stars.three(),
        moves: const MoveCount(12),
        timeSeconds: 45,
      );

  test('execute envía el score al repo cuando la red responde', () async {
    // Arrange
    when(repository.submitScore(any)).thenAnswer((_) async {});
    // Act
    await useCase.execute(entry());
    // Assert
    verify(repository.submitScore(entry())).called(1);
  });

  test('execute traga el error de red y lo loggea (no relanza)', () async {
    // Arrange
    when(repository.submitScore(any)).thenThrow(Exception('red caída'));
    // Act — no debe lanzar
    await useCase.execute(entry());
    // Assert
    verify(logger.error(any, any, any)).called(1);
  });
}
