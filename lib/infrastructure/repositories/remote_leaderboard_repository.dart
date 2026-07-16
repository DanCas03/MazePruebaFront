import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../../domain/game_core/value_objects/score.dart';
import '../../domain/game_core/value_objects/stars.dart';
import '../../domain/leaderboard/entities/global_leaderboard.dart';
import '../../domain/leaderboard/entities/leaderboard_entry.dart';
import '../../domain/leaderboard/entities/score_entry.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';
import '../../domain/leaderboard/value_objects/canonical_result.dart';
import '../data_sources/remote/leaderboard_remote_data_source.dart';

/// Adapter: implementa el puerto mapeando entre el dominio y el shape JSON del
/// back — envío al contrato ADR 0006 (`_toRequestJson`) y lectura del
/// contrato back#9 (`_fromJson`). Calca el estilo de `RemoteProgressRepository`.
class RemoteLeaderboardRepository implements ILeaderboardRepository {
  final LeaderboardRemoteDataSource _dataSource;
  // AOP: puerto de logging inyectado (DIP) para reportar filas descartadas sin
  // acoplar el repo al package concreto de logs.
  final ILoggerService _log;
  RemoteLeaderboardRepository(this._dataSource, this._log);

  @override
  Future<CanonicalResult> submitScore(ScoreEntry entry) async {
    final json = await _dataSource.postScore(_toRequestJson(entry));
    return _toCanonicalResult(json);
  }

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

  @override
  Future<GlobalLeaderboard> getGlobalLeaderboard() async {
    final json = await _dataSource.fetchGlobalLeaderboard();
    // Misma degradación con gracia que `getLeaderboard`: una fila corrupta del
    // top se salta loggeándola; un `me` corrupto degrada a `null` ("sin
    // clasificar") en lugar de tumbar la pantalla entera.
    final top = <GlobalLeaderboardEntry>[];
    for (final row in (json['top'] as List<dynamic>? ?? const [])) {
      try {
        top.add(_globalEntryFromJson(row as Map<String, dynamic>));
      } catch (e) {
        _log.warn(
          'Fila de leaderboard general inválida, se omite: $e',
          'RemoteLeaderboardRepository',
        );
      }
    }
    GlobalLeaderboardEntry? me;
    final rawMe = json['me'];
    if (rawMe != null) {
      try {
        me = _globalEntryFromJson(rawMe as Map<String, dynamic>);
      } catch (e) {
        _log.warn(
          'Fila propia del leaderboard general inválida, se omite: $e',
          'RemoteLeaderboardRepository',
        );
      }
    }
    return GlobalLeaderboard(top: top, me: me);
  }

  GlobalLeaderboardEntry _globalEntryFromJson(Map<String, dynamic> j) =>
      GlobalLeaderboardEntry(
        username: j['username'] as String,
        totalScore: j['totalScore'] as int,
        totalStars: j['totalStars'] as int,
        rank: j['rank'] as int,
      );

  /// Métricas crudas del run (ADR 0006): el back deriva el resultado canónico
  /// a partir de ellas. `previewScore` viaja solo con fines de auditoría/
  /// telemetría; el back no lo usa para calcular el canónico.
  Map<String, dynamic> _toRequestJson(ScoreEntry e) => {
        'levelId': e.levelId.value,
        'moves': e.moves.value,
        'timeSeconds': e.timeSeconds,
        'collisions': e.collisions,
        'previewScore': e.score.value,
      };

  /// Parsea la respuesta del POST `{score, stars}` al resultado canónico.
  /// Un campo faltante o `stars` fuera de `[1,3]` lanza (propaga al use case,
  /// que decide cómo degradar).
  CanonicalResult _toCanonicalResult(Map<String, dynamic> j) =>
      CanonicalResult(
        score: Score(j['score'] as int),
        stars: Stars.fromValue(j['stars'] as int),
      );

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
