import '../../board/value_objects/level_id.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/score_entry.dart';

/// Puerto (DIP) del leaderboard. Interfaz cohesiva alrededor del agregado
/// ranking: escritura (`submitScore`, front#16) y lectura (`getLeaderboard`,
/// front#17). La infraestructura decide el transporte (Dio).
abstract interface class ILeaderboardRepository {
  /// Envía el score de una partida ganada (`POST /scores`, back#7). Lanza si la
  /// red falla; el use case de envío captura el error para no romper el flujo de
  /// victoria (front#16).
  Future<void> submitScore(ScoreEntry entry);

  /// Lee el ranking de un nivel (`GET /leaderboard/:levelId`, back#9), ya
  /// ordenado por score desc. [limit] acota el top-N solicitado (el back aplica
  /// su propio default y máximo). Propaga el error para que la UI muestre estado
  /// de error (a diferencia del envío fire-and-forget).
  Future<List<LeaderboardEntry>> getLeaderboard(LevelId levelId, {int? limit});
}
