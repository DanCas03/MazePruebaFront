import '../entities/score_entry.dart';

/// Puerto (DIP) del leaderboard (`POST /scores`, back#7). La infraestructura
/// decide el transporte (Dio). Interfaz pequeña y cohesiva (ISP): front#17
/// añadirá la lectura del ranking (`getLeaderboard`).
abstract interface class ILeaderboardRepository {
  /// Envía el score de una partida ganada. Lanza si la red falla; el use case
  /// captura el error para no romper el flujo de victoria (front#16).
  Future<void> submitScore(ScoreEntry entry);
}
