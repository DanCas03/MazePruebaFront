import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../../domain/game_core/value_objects/score.dart';
import '../../domain/game_core/value_objects/stars.dart';
import '../../domain/leaderboard/entities/leaderboard_entry.dart';
import '../../domain/leaderboard/entities/score_entry.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';
import '../data_sources/remote/leaderboard_remote_data_source.dart';

/// Adapter: implementa el puerto mapeando entre el dominio y el shape JSON del
/// back — envío al contrato back#7 (`_toJson`) y lectura del contrato back#9
/// (`_fromJson`). Calca el estilo de `RemoteProgressRepository`.
class RemoteLeaderboardRepository implements ILeaderboardRepository {
  final LeaderboardRemoteDataSource _dataSource;
  RemoteLeaderboardRepository(this._dataSource);

  @override
  Future<void> submitScore(ScoreEntry entry) =>
      _dataSource.postScore(_toJson(entry));

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(
    LevelId levelId, {
    int? limit,
  }) async {
    final rows = await _dataSource.fetchLeaderboard(levelId.value, limit: limit);
    // El back ya devuelve las filas ordenadas por score desc; se preserva ese
    // orden (el rango es posicional).
    return rows
        .map((row) => _fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Map<String, dynamic> _toJson(ScoreEntry e) => {
        'levelId': e.levelId.value,
        'score': e.score.value,
        'stars': e.stars.value,
        'moves': e.moves.value,
        'timeSeconds': e.timeSeconds,
      };

  LeaderboardEntry _fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        id: j['id'] as String,
        userId: j['userId'] as String,
        levelId: LevelId(j['levelId'] as String),
        score: Score(j['score'] as int),
        stars: Stars.fromValue(j['stars'] as int),
        moves: MoveCount(j['moves'] as int),
        timeSeconds: j['timeSeconds'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
