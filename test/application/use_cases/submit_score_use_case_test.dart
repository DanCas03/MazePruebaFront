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
import 'package:flutter_arrow_maze/domain/leaderboard/value_objects/canonical_result.dart';

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
        collisions: 2,
      );

  test('execute devuelve el canónico cuando la red responde', () async {
    // Arrange
    final canonical = CanonicalResult(score: Score(900), stars: const Stars.two());
    when(repository.submitScore(any)).thenAnswer((_) async => canonical);
    // Act
    final result = await useCase.execute(entry());
    // Assert
    verify(repository.submitScore(entry())).called(1);
    expect(result, canonical);
  });

  test('execute devuelve null y loggea el error, sin relanzar (fallo de red)',
      () async {
    // Arrange
    when(repository.submitScore(any)).thenThrow(Exception('red caída'));
    // Act — no debe lanzar
    final result = await useCase.execute(entry());
    // Assert
    expect(result, isNull);
    verify(logger.error(any, any, any)).called(1);
  });
}
