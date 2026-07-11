import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/leaderboard_remote_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_leaderboard_repository.dart';

import 'remote_leaderboard_repository_test.mocks.dart';

@GenerateMocks([LeaderboardRemoteDataSource])
void main() {
  late MockLeaderboardRemoteDataSource dataSource;
  late RemoteLeaderboardRepository repository;

  setUp(() {
    dataSource = MockLeaderboardRemoteDataSource();
    repository = RemoteLeaderboardRepository(dataSource);
  });

  ScoreEntry entry() => ScoreEntry(
        levelId: LevelId('7'),
        score: Score(1200),
        stars: const Stars.three(),
        moves: const MoveCount(12),
        timeSeconds: 45,
      );

  test('submitScore postea el JSON del contrato back', () async {
    // Arrange
    when(dataSource.postScore(any)).thenAnswer((_) async {});
    // Act
    await repository.submitScore(entry());
    // Assert — se captura el Map y se compara en profundidad (el `==` de Map es
    // por identidad, así que no se puede pasar un literal directo a `verify`).
    final captured = verify(dataSource.postScore(captureAny)).captured.single;
    expect(captured, {
      'levelId': '7',
      'score': 1200,
      'stars': 3,
      'moves': 12,
      'timeSeconds': 45,
    });
  });

  test('submitScore propaga el error del datasource', () async {
    // Arrange
    when(dataSource.postScore(any)).thenThrow(Exception('red caída'));
    // Act / Assert
    expect(() => repository.submitScore(entry()), throwsException);
  });
}
