import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/score_entry.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/leaderboard_remote_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_leaderboard_repository.dart';

import 'remote_leaderboard_repository_test.mocks.dart';

/// Logger de prueba: registra los `warn` para verificar que una fila inválida se
/// loggea al saltarse (AOP), sin depender de codegen para un puerto trivial.
class _RecordingLogger implements ILoggerService {
  final List<String> warnings = [];
  @override
  void warn(String message, String context) => warnings.add(message);
  @override
  void log(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
}

@GenerateMocks([LeaderboardRemoteDataSource])
void main() {
  late MockLeaderboardRemoteDataSource dataSource;
  late _RecordingLogger logger;
  late RemoteLeaderboardRepository repository;

  setUp(() {
    dataSource = MockLeaderboardRemoteDataSource();
    logger = _RecordingLogger();
    repository = RemoteLeaderboardRepository(dataSource, logger);
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

  Map<String, dynamic> row({
    String id = 'row-1',
    String userId = 'user-1',
    int score = 1200,
    int stars = 3,
  }) =>
      {
        'id': id,
        'userId': userId,
        'levelId': '7',
        'score': score,
        'stars': stars,
        'moves': 12,
        'timeSeconds': 45,
        'createdAt': '2026-07-01T10:30:00.000Z',
      };

  test('getLeaderboard mapea las filas JSON del contrato back#9 al dominio',
      () async {
    // Arrange
    when(dataSource.fetchLeaderboard('7', limit: anyNamed('limit')))
        .thenAnswer((_) async => [row()]);
    // Act
    final entries = await repository.getLeaderboard(LevelId('7'));
    // Assert
    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e, isA<LeaderboardEntry>());
    expect(e.id, 'row-1');
    expect(e.userId, 'user-1');
    expect(e.levelId.value, '7');
    expect(e.score.value, 1200);
    expect(e.stars.value, 3);
    expect(e.moves.value, 12);
    expect(e.timeSeconds, 45);
    expect(e.createdAt, DateTime.utc(2026, 7, 1, 10, 30));
  });

  test('getLeaderboard preserva el orden del back (score desc) y pasa el limit',
      () async {
    // Arrange — el back devuelve ya ordenado por score desc
    when(dataSource.fetchLeaderboard('7', limit: 2)).thenAnswer(
      (_) async => [row(id: 'a', score: 900), row(id: 'b', score: 500)],
    );
    // Act
    final entries = await repository.getLeaderboard(LevelId('7'), limit: 2);
    // Assert — se preserva el orden recibido y se reenvía el limit
    expect(entries.map((e) => e.id).toList(), ['a', 'b']);
    verify(dataSource.fetchLeaderboard('7', limit: 2)).called(1);
  });

  test('getLeaderboard propaga el error del datasource', () async {
    // Arrange
    when(dataSource.fetchLeaderboard(any, limit: anyNamed('limit')))
        .thenThrow(Exception('red caída'));
    // Act / Assert
    expect(() => repository.getLeaderboard(LevelId('7')), throwsException);
  });

  test(
      'getLeaderboard omite las filas inválidas loggeándolas, sin tumbar el '
      'ranking', () async {
    // Arrange — la fila del medio trae `stars` fuera de la cota [1,3], que hoy
    // haría lanzar a `Stars.fromValue` y convertiría toda la pantalla en error.
    when(dataSource.fetchLeaderboard('7', limit: anyNamed('limit'))).thenAnswer(
      (_) async => [
        row(id: 'ok-1', score: 900),
        row(id: 'bad', stars: 9),
        row(id: 'ok-2', score: 500),
      ],
    );
    // Act
    final entries = await repository.getLeaderboard(LevelId('7'));
    // Assert — solo las dos válidas, en orden; la corrupta se saltó y se loggeó.
    expect(entries.map((e) => e.id).toList(), ['ok-1', 'ok-2']);
    expect(logger.warnings, hasLength(1));
  });
}
