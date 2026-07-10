import '../../domain/leaderboard/entities/score_entry.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';
import '../data_sources/remote/leaderboard_remote_data_source.dart';

/// Adapter: implementa el puerto mapeando `ScoreEntry` al shape JSON de
/// `/scores` (contrato back#7). Calca el estilo de `RemoteProgressRepository`.
class RemoteLeaderboardRepository implements ILeaderboardRepository {
  final LeaderboardRemoteDataSource _dataSource;
  RemoteLeaderboardRepository(this._dataSource);

  @override
  Future<void> submitScore(ScoreEntry entry) =>
      _dataSource.postScore(_toJson(entry));

  Map<String, dynamic> _toJson(ScoreEntry e) => {
        'levelId': e.levelId.value,
        'score': e.score.value,
        'stars': e.stars.value,
        'moves': e.moves.value,
        'timeSeconds': e.timeSeconds,
      };
}
