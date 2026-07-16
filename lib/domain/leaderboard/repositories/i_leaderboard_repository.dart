import '../../board/value_objects/level_id.dart';
import '../../leaderboard/value_objects/canonical_result.dart';
import '../entities/global_leaderboard.dart';
import '../entities/leaderboard_entry.dart';
import '../entities/score_entry.dart';

/// Puerto (DIP) del leaderboard. Interfaz cohesiva alrededor del agregado
/// ranking: escritura (`submitScore`, front#16) y lectura (`getLeaderboard`,
/// front#17). La infraestructura decide el transporte (Dio).
abstract interface class ILeaderboardRepository {
  /// Envía las métricas crudas de una partida ganada (`POST /scores`, ADR
  /// 0006) y devuelve el resultado CANÓNICO derivado por el back. Lanza si la
  /// red falla o la respuesta es inválida; el use case de envío captura el
  /// error para no romper el flujo de victoria (front#16).
  Future<CanonicalResult> submitScore(ScoreEntry entry);

  /// Lee el ranking de un nivel (`GET /leaderboard/:levelId`, back#9), ya
  /// ordenado por score desc. [limit] acota el top-N solicitado (el back aplica
  /// su propio default y máximo). Propaga el error para que la UI muestre estado
  /// de error (a diferencia del envío fire-and-forget).
  Future<List<LeaderboardEntry>> getLeaderboard(LevelId levelId, {int? limit});

  /// Lee el ranking general de jugadores (`GET /leaderboard`, ADR 0006):
  /// top-N por total de puntos de campaña más la fila propia (`me`, o `null`
  /// si el jugador aún no clasifica). Requiere sesión (JWT). Propaga el error
  /// para que la UI muestre estado de error, igual que [getLeaderboard].
  Future<GlobalLeaderboard> getGlobalLeaderboard();
}
