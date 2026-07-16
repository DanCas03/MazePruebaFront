import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';
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
        collisions: 2,
      );

  test('submitScore postea EXACTAMENTE el contrato ADR 0006 y parsea el canónico',
      () async {
    // Arrange
    when(dataSource.postScore(any))
        .thenAnswer((_) async => {'score': 900, 'stars': 2});
    // Act
    final result = await repository.submitScore(entry());
    // Assert — se captura el Map y se compara en profundidad (el `==` de Map es
    // por identidad, así que no se puede pasar un literal directo a `verify`).
    final captured = verify(dataSource.postScore(captureAny)).captured.single;
    expect(captured, {
      'levelId': '7',
      'moves': 12,
      'timeSeconds': 45,
      'collisions': 2,
      'previewScore': 1200,
    });
    expect(result.score.value, 900);
    expect(result.stars.value, 2);
  });

  test('submitScore propaga el error del datasource', () async {
    // Arrange
    when(dataSource.postScore(any)).thenThrow(Exception('red caída'));
    // Act / Assert
    expect(() => repository.submitScore(entry()), throwsException);
  });

  test('submitScore lanza cuando la respuesta no trae los campos canónicos',
      () async {
    // Arrange — falta 'stars' por completo.
    when(dataSource.postScore(any)).thenAnswer((_) async => {'score': 900});
    // Act / Assert
    expect(() => repository.submitScore(entry()), throwsA(isA<TypeError>()));
  });

  test('submitScore lanza cuando stars está fuera de la cota [1,3]', () async {
    // Arrange
    when(dataSource.postScore(any))
        .thenAnswer((_) async => {'score': 900, 'stars': 9});
    // Act / Assert
    expect(() => repository.submitScore(entry()), throwsArgumentError);
  });

  Map<String, dynamic> row({
    String id = 'row-1',
    String userId = 'user-1',
    String username = 'ana',
    int score = 1200,
    int stars = 3,
  }) =>
      {
        'id': id,
        'userId': userId,
        'username': username,
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
    expect(e.username, 'ana');
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

  Map<String, dynamic> globalRow({
    String username = 'ana',
    int totalScore = 900,
    int totalStars = 12,
    int? rank = 1,
  }) =>
      {
        'username': username,
        'totalScore': totalScore,
        'totalStars': totalStars,
        if (rank != null) 'rank': rank,
      };

  test('getGlobalLeaderboard parsea el contrato {top, me} de ADR 0006',
      () async {
    // Arrange
    when(dataSource.fetchGlobalLeaderboard()).thenAnswer(
      (_) async => {
        'top': [
          globalRow(rank: 1),
          globalRow(username: 'leo', totalScore: 700, totalStars: 9, rank: 2),
        ],
        'me': globalRow(username: 'dan', totalScore: 120, totalStars: 3, rank: 42),
      },
    );
    // Act
    final board = await repository.getGlobalLeaderboard();
    // Assert
    expect(board.top, hasLength(2));
    expect(board.top.first, isA<GlobalLeaderboardEntry>());
    expect(board.top.first.username, 'ana');
    expect(board.top.first.totalScore, 900);
    expect(board.top.first.totalStars, 12);
    expect(board.top.first.rank, 1);
    expect(board.me, isNotNull);
    expect(board.me!.username, 'dan');
    expect(board.me!.rank, 42);
    expect(board.meIsInTop, isFalse);
  });

  test('getGlobalLeaderboard mapea me:null a un jugador sin clasificar',
      () async {
    // Arrange
    when(dataSource.fetchGlobalLeaderboard()).thenAnswer(
      (_) async => {
        'top': [globalRow()],
        'me': null,
      },
    );
    // Act
    final board = await repository.getGlobalLeaderboard();
    // Assert
    expect(board.top, hasLength(1));
    expect(board.me, isNull);
  });

  test(
      'getGlobalLeaderboard omite una fila corrupta del top loggeándola, sin '
      'tumbar el resto', () async {
    // Arrange — a la fila del medio le falta `rank` (cast a int falla).
    when(dataSource.fetchGlobalLeaderboard()).thenAnswer(
      (_) async => {
        'top': [
          globalRow(rank: 1),
          globalRow(username: 'bad', rank: null),
          globalRow(username: 'leo', rank: 3),
        ],
        'me': null,
      },
    );
    // Act
    final board = await repository.getGlobalLeaderboard();
    // Assert
    expect(board.top.map((e) => e.username).toList(), ['ana', 'leo']);
    expect(logger.warnings, hasLength(1));
  });

  test('getGlobalLeaderboard degrada un me corrupto a null con warn', () async {
    // Arrange — me trae rank inválido (0 viola la invariante de la entidad).
    when(dataSource.fetchGlobalLeaderboard()).thenAnswer(
      (_) async => {
        'top': [globalRow()],
        'me': globalRow(username: 'dan', rank: 0),
      },
    );
    // Act
    final board = await repository.getGlobalLeaderboard();
    // Assert — la pantalla no se cae: queda "sin clasificar" y se loggea.
    expect(board.top, hasLength(1));
    expect(board.me, isNull);
    expect(logger.warnings, hasLength(1));
  });

  test('getGlobalLeaderboard propaga el error del datasource', () async {
    // Arrange
    when(dataSource.fetchGlobalLeaderboard()).thenThrow(Exception('red caída'));
    // Act / Assert
    expect(() => repository.getGlobalLeaderboard(), throwsException);
  });
}
