import 'package:equatable/equatable.dart';

import '../../board/value_objects/level_id.dart';
import '../../game_core/value_objects/move_count.dart';
import '../../game_core/value_objects/score.dart';
import '../../game_core/value_objects/stars.dart';

/// Resultado de una partida ganada listo para el leaderboard (contrato back#7:
/// `{levelId, score, stars, moves, timeSeconds}`). Agrega los VOs de dominio del
/// run; `timeSeconds` es el tiempo transcurrido. Dart puro, igualdad por valor.
class ScoreEntry extends Equatable {
  final LevelId levelId;
  final Score score;
  final Stars stars;
  final MoveCount moves;
  final int timeSeconds;

  ScoreEntry({
    required this.levelId,
    required this.score,
    required this.stars,
    required this.moves,
    required this.timeSeconds,
  }) {
    // Invariante validada en runtime (no `assert`, que se elimina en release).
    if (timeSeconds < 0) {
      throw ArgumentError('timeSeconds must not be negative');
    }
  }

  @override
  List<Object?> get props => [levelId, score, stars, moves, timeSeconds];
}
