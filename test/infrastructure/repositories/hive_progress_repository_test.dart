import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/local/hive_level_progress_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/models/level_progress_hive_model.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/hive_progress_repository.dart';

import 'hive_progress_repository_test.mocks.dart';

@GenerateMocks([HiveLocalDataSource])
void main() {
  late MockHiveLocalDataSource mockDataSource;
  late HiveProgressRepository repository;

  setUp(() {
    mockDataSource = MockHiveLocalDataSource();
    repository = HiveProgressRepository(mockDataSource);
  });

  group('getProgress', () {
    test('returns MoveCount mapped from the model when present', () async {
      // Arrange
      final levelId = LevelId('level-1');
      when(mockDataSource.getProgress('level-1')).thenReturn(
        LevelProgressHiveModel(
            levelId: 'level-1', moveCount: 7, completed: false),
      );

      // Act
      final result = await repository.getProgress(levelId);

      // Assert
      expect(result, const MoveCount(7));
      verify(mockDataSource.getProgress('level-1')).called(1);
    });

    test('returns null when the data source has no progress', () async {
      // Arrange
      final levelId = LevelId('level-1');
      when(mockDataSource.getProgress('level-1')).thenReturn(null);

      // Act
      final result = await repository.getProgress(levelId);

      // Assert
      expect(result, isNull);
    });
  });

  group('saveProgress', () {
    test('delegates the unwrapped values to the data source', () async {
      // Arrange
      final levelId = LevelId('level-2');
      const moves = MoveCount(3);
      when(mockDataSource.saveProgress('level-2', 3))
          .thenAnswer((_) async {});

      // Act
      await repository.saveProgress(levelId, moves);

      // Assert
      verify(mockDataSource.saveProgress('level-2', 3)).called(1);
    });
  });

  group('markCompleted', () {
    test('delegates the level id value to the data source', () async {
      // Arrange
      final levelId = LevelId('level-3');
      when(mockDataSource.markCompleted('level-3'))
          .thenAnswer((_) async {});

      // Act
      await repository.markCompleted(levelId);

      // Assert
      verify(mockDataSource.markCompleted('level-3')).called(1);
    });
  });

  group('isCompleted', () {
    test('returns the boolean reported by the data source', () async {
      // Arrange
      final levelId = LevelId('level-4');
      when(mockDataSource.isCompleted('level-4')).thenReturn(true);

      // Act
      final result = await repository.isCompleted(levelId);

      // Assert
      expect(result, isTrue);
      verify(mockDataSource.isCompleted('level-4')).called(1);
    });

    test('returns false when the data source reports false', () async {
      // Arrange
      final levelId = LevelId('level-5');
      when(mockDataSource.isCompleted('level-5')).thenReturn(false);

      // Act
      final result = await repository.isCompleted(levelId);

      // Assert
      expect(result, isFalse);
    });
  });

  group('getAll', () {
    test('should_map_all_models_to_level_progress_when_present', () async {
      // Arrange
      when(mockDataSource.getAllProgress()).thenReturn([
        LevelProgressHiveModel(
            levelId: '1', moveCount: 5, completed: true, bestScore: 900, bestStars: 3),
        LevelProgressHiveModel(
            levelId: '2', moveCount: 0, completed: false),
      ]);
      // Act
      final result = await repository.getAll();
      // Assert
      expect(result, hasLength(2));
      expect(result.first.levelId, LevelId('1'));
      expect(result.first.bestScore, 900);
      expect(result.first.bestStars, 3);
      expect(result.last.bestScore, isNull);
    });
  });

  group('upsertAll', () {
    test('should_upsert_each_entry_when_saving_merged_progress', () async {
      // Arrange
      when(mockDataSource.upsertProgress(any, any, any, any))
          .thenAnswer((_) async {});
      final progress = [
        LevelProgress(
            levelId: LevelId('1'), completed: true, bestScore: 900, bestStars: 3),
      ];
      // Act
      await repository.upsertAll(progress);
      // Assert
      verify(mockDataSource.upsertProgress('1', true, 900, 3)).called(1);
    });
  });
}
