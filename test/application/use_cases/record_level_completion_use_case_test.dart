import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/application/use_cases/record_level_completion_use_case.dart';

import 'record_level_completion_use_case_test.mocks.dart';

@GenerateMocks([ILevelProgressRepository, ILoggerService])
void main() {
  late MockILevelProgressRepository progress;
  late MockILoggerService logger;
  late RecordLevelCompletionUseCase useCase;

  setUp(() {
    progress = MockILevelProgressRepository();
    logger = MockILoggerService();
    useCase = RecordLevelCompletionUseCase(progress, logger);
    when(progress.upsertAll(any)).thenAnswer((_) async {});
  });

  test('should_persist_completed_progress_with_run_stats_when_no_prior_exists',
      () async {
    // Arrange
    when(progress.getAll()).thenAnswer((_) async => <LevelProgress>[]);

    // Act
    await useCase.execute(LevelId('7'), score: 8200, stars: 2);

    // Assert
    final persisted =
        verify(progress.upsertAll(captureAny)).captured.single as List<LevelProgress>;
    expect(persisted.single.levelId, LevelId('7'));
    expect(persisted.single.completed, isTrue);
    expect(persisted.single.bestScore, 8200);
    expect(persisted.single.bestStars, 2);
  });

  test('should_keep_the_best_score_and_stars_when_replaying_worse', () async {
    // Arrange — ya existe un récord mejor (3 estrellas, 9000)
    when(progress.getAll()).thenAnswer((_) async => [
          LevelProgress(
            levelId: LevelId('7'),
            completed: true,
            bestScore: 9000,
            bestStars: 3,
          ),
        ]);

    // Act — se rejuega peor (2 estrellas, 8200)
    await useCase.execute(LevelId('7'), score: 8200, stars: 2);

    // Assert — conserva el récord previo, no lo degrada
    final persisted =
        verify(progress.upsertAll(captureAny)).captured.single as List<LevelProgress>;
    expect(persisted.single.bestScore, 9000);
    expect(persisted.single.bestStars, 3);
    expect(persisted.single.completed, isTrue);
  });

  test('should_upgrade_the_record_when_replaying_better', () async {
    // Arrange — récord previo modesto
    when(progress.getAll()).thenAnswer((_) async => [
          LevelProgress(
            levelId: LevelId('7'),
            completed: true,
            bestScore: 5000,
            bestStars: 1,
          ),
        ]);

    // Act — mejor run
    await useCase.execute(LevelId('7'), score: 8200, stars: 2);

    // Assert
    final persisted =
        verify(progress.upsertAll(captureAny)).captured.single as List<LevelProgress>;
    expect(persisted.single.bestScore, 8200);
    expect(persisted.single.bestStars, 2);
  });

  test('should_swallow_and_log_error_when_persistence_fails', () async {
    // Arrange
    when(progress.getAll()).thenThrow(Exception('hive down'));

    // Act — no debe propagar (es fire-and-forget desde el observer)
    Future<void> act() => useCase.execute(LevelId('7'), score: 100, stars: 1);

    // Assert
    await expectLater(act(), completes);
    verify(logger.error(any, any, any)).called(1);
  });
}
