import 'package:equatable/equatable.dart';

import '../../board/value_objects/level_id.dart';
import '../../game_core/value_objects/move_count.dart';
import '../../game_core/value_objects/score.dart';
import '../../game_core/value_objects/stars.dart';

/// Fila del ranking leída de `GET /leaderboard/:levelId` (contrato back#9).
///
/// A diferencia de `ScoreEntry` (payload de envío, front#16), es el modelo de
/// lectura: agrega la identidad persistida (`id`, `userId`) y la marca temporal
/// `createdAt`. El rango es posicional —el back devuelve las filas ordenadas por
/// score desc— y no un campo del cable. Dart puro, igualdad por valor.
class LeaderboardEntry extends Equatable {
  final String id;
  final String userId;
  final LevelId levelId;
  final Score score;
  final Stars stars;
  final MoveCount moves;
  final int timeSeconds;
  final DateTime createdAt;

  LeaderboardEntry({
    required this.id,
    required this.userId,
    required this.levelId,
    required this.score,
    required this.stars,
    required this.moves,
    required this.timeSeconds,
    required this.createdAt,
  }) {
    // Invariante validada en runtime (coherente con ScoreEntry): el tiempo
    // transcurrido nunca es negativo.
    if (timeSeconds < 0) {
      throw ArgumentError('timeSeconds must not be negative');
    }
  }

  @override
  List<Object?> get props =>
      [id, userId, levelId, score, stars, moves, timeSeconds, createdAt];
}
