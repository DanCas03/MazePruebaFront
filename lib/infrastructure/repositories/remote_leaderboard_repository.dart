import '../../core/aspects/i_logger_service.dart';
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
  // AOP: puerto de logging inyectado (DIP) para reportar filas descartadas sin
  // acoplar el repo al package concreto de logs.
  final ILoggerService _log;
  RemoteLeaderboardRepository(this._dataSource, this._log);

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
    // orden (el rango es posicional). Una fila corrupta (p.ej. `stars` fuera de
    // `[1,3]` o un campo faltante) se SALTA loggeándola, en lugar de tumbar todo
    // el ranking: degradación con gracia ante datos de red imperfectos. La
    // estrictez de dominio (`Stars.fromValue`) se conserva; solo se aísla su
    // efecto a la fila afectada.
    final entries = <LeaderboardEntry>[];
    for (final row in rows) {
      try {
        entries.add(_fromJson(row as Map<String, dynamic>));
      } catch (e) {
        _log.warn(
          'Fila de leaderboard inválida, se omite: $e',
          'RemoteLeaderboardRepository',
        );
      }
    }
    return List.unmodifiable(entries);
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
        username: j['username'] as String,
        levelId: LevelId(j['levelId'] as String),
        score: Score(j['score'] as int),
        stars: Stars.fromValue(j['stars'] as int),
        moves: MoveCount(j['moves'] as int),
        timeSeconds: j['timeSeconds'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
