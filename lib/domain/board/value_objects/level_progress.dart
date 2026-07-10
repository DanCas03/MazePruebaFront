import 'package:equatable/equatable.dart';

import 'level_id.dart';

/// VO inmutable: el progreso reconciliable de un nivel (completado + mejor
/// score/estrellas). Espejo de los campos opcionales de `/progress` (back#8).
///
/// Usa `int?` en vez del `Score`/`Stars` VO de front#12 (aún no mergeado; #18 no
/// está bloqueado por él): mantiene esta feature autocontenida. `bestScore`/
/// `bestStars` son null hasta que exista un ScoreEntry para el nivel.
class LevelProgress extends Equatable {
  final LevelId levelId;
  final bool completed;
  final int? bestScore;
  final int? bestStars;

  LevelProgress({
    required this.levelId,
    required this.completed,
    this.bestScore,
    this.bestStars,
  }) {
    // Invariantes validadas en runtime (no `assert`, que se elimina en release),
    // coherentes con el VO Score/Stars del back (Min(0) / 1..3).
    if (bestScore != null && bestScore! < 0) {
      throw ArgumentError('bestScore must be non-negative, got $bestScore');
    }
    if (bestStars != null && (bestStars! < 1 || bestStars! > 3)) {
      throw ArgumentError('bestStars must be in 1..3, got $bestStars');
    }
  }

  @override
  List<Object?> get props => [levelId, completed, bestScore, bestStars];
}
