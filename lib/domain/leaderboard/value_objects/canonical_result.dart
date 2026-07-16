import 'package:equatable/equatable.dart';

import '../../game_core/value_objects/score.dart';
import '../../game_core/value_objects/stars.dart';

/// Resultado canónico derivado por el back a partir de las métricas crudas del
/// run (ADR 0006). Sustituye el preview cliente (`ScoreEntry.score`/`.stars`)
/// una vez que el `POST /scores` responde; la pantalla de victoria se
/// reconcilia con este valor.
class CanonicalResult extends Equatable {
  final Score score;
  final Stars stars;

  const CanonicalResult({required this.score, required this.stars});

  @override
  List<Object?> get props => [score, stars];
}
