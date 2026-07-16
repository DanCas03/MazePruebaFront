import 'package:equatable/equatable.dart';

import '../../board/value_objects/level_id.dart';
import '../../game_core/value_objects/move_count.dart';
import '../../game_core/value_objects/score.dart';
import '../../game_core/value_objects/stars.dart';

/// Resultado de una partida ganada listo para enviar al back (ADR 0006:
/// `{levelId, moves, timeSeconds, collisions, previewScore}`). Agrega los VOs
/// de dominio del run; `timeSeconds` es el tiempo transcurrido. [score] y
/// [stars] son el PREVIEW calculado en el cliente (`Score.fromRun` /
/// `Stars.rate`): el back deriva el resultado CANÓNICO a partir de las
/// métricas crudas del run y lo devuelve en la respuesta del POST
/// (`CanonicalResult`), con el que se reconcilia la pantalla de victoria. Dart
/// puro, igualdad por valor.
class ScoreEntry extends Equatable {
  final LevelId levelId;
  final Score score;
  final Stars stars;
  final MoveCount moves;
  final int timeSeconds;
  final int collisions;

  ScoreEntry({
    required this.levelId,
    required this.score,
    required this.stars,
    required this.moves,
    required this.timeSeconds,
    required this.collisions,
  }) {
    // Invariantes validadas en runtime (no `assert`, que se elimina en release).
    if (timeSeconds < 0) {
      throw ArgumentError('timeSeconds must not be negative');
    }
    if (collisions < 0) {
      throw ArgumentError('collisions must not be negative');
    }
  }

  @override
  List<Object?> get props =>
      [levelId, score, stars, moves, timeSeconds, collisions];
}
