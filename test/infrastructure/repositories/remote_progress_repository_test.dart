import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/remote_progress_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_progress_repository.dart';

import 'remote_progress_repository_test.mocks.dart';

@GenerateMocks([RemoteProgressDataSource])
void main() {
  late MockRemoteProgressDataSource mockDataSource;
  late RemoteProgressRepository repository;

  setUp(() {
    mockDataSource = MockRemoteProgressDataSource();
    repository = RemoteProgressRepository(mockDataSource);
  });

  group('pull', () {
    test('should_map_backend_rows_to_level_progress_when_pulling', () async {
      // Arrange
      when(mockDataSource.getProgress()).thenAnswer((_) async => [
            {'levelId': '1', 'completed': true, 'bestScore': 1200, 'bestStars': 3},
            {'levelId': '2', 'completed': false, 'bestScore': null, 'bestStars': null},
          ]);
      // Act
      final result = await repository.pull();
      // Assert
      expect(result, hasLength(2));
      expect(result.first.levelId, LevelId('1'));
      expect(result.first.bestScore, 1200);
      expect(result.last.bestScore, isNull);
      expect(result.last.completed, isFalse);
    });
  });

  group('push', () {
    test('should_serialize_progress_and_map_merged_response_when_pushing', () async {
      // Arrange
      when(mockDataSource.postProgress(any)).thenAnswer((_) async => [
            {'levelId': '1', 'completed': true, 'bestScore': 1200, 'bestStars': 3},
          ]);
      final progress = [
        LevelProgress(
            levelId: LevelId('1'), completed: true, bestScore: 1200, bestStars: 3),
        LevelProgress(levelId: LevelId('2'), completed: true),
      ];
      // Act
      final result = await repository.push(progress);
      // Assert
      final captured = verify(mockDataSource.postProgress(captureAny)).captured.single
          as List<Map<String, dynamic>>;
      expect(captured.first,
          {'levelId': '1', 'completed': true, 'bestScore': 1200, 'bestStars': 3});
      // null score/stars se omiten del payload (campos opcionales del back)
      expect(captured.last, {'levelId': '2', 'completed': true});
      expect(result.single.levelId, LevelId('1'));
    });
  });
}
