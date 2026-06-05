// lib/domain/board/entities/level_progress_entry.dart

import '../../game_core/value_objects/level_id.dart';
import '../../game_core/value_objects/move_count.dart';

/// Entidad de dominio que representa el progreso de un nivel: si fue
/// completado y la mejor marca de movimientos.
///
/// DDD: se construye con Value Objects ([LevelId], [MoveCount]) y no conoce
/// ninguna tecnología de persistencia. El mapeo a/desde la base de datos vive
/// en la Capa 4 (infraestructura), nunca aquí.
class LevelProgressEntry {
  final LevelId levelId;
  final bool isCompleted;
  final MoveCount bestMoveCount;

  const LevelProgressEntry({
    required this.levelId,
    required this.isCompleted,
    required this.bestMoveCount,
  });

  /// Devuelve una copia marcada como completada, conservando la MEJOR marca
  /// (la menor cantidad de movimientos). Mantiene la entidad inmutable.
  LevelProgressEntry withBestMove(MoveCount candidate) {
    final best = (isCompleted && bestMoveCount.value < candidate.value)
        ? bestMoveCount
        : candidate;
    return LevelProgressEntry(
      levelId: levelId,
      isCompleted: true,
      bestMoveCount: best,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LevelProgressEntry &&
          other.levelId == levelId &&
          other.isCompleted == isCompleted &&
          other.bestMoveCount == bestMoveCount;

  @override
  int get hashCode => Object.hash(levelId, isCompleted, bestMoveCount);
}
