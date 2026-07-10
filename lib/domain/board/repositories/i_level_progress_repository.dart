import '../value_objects/level_id.dart';
import '../value_objects/level_progress.dart';
import '../../game_core/value_objects/move_count.dart';

abstract interface class ILevelProgressRepository {
  Future<MoveCount?> getProgress(LevelId levelId);
  Future<void> saveProgress(LevelId levelId, MoveCount moves);
  Future<void> markCompleted(LevelId levelId);
  Future<bool> isCompleted(LevelId levelId);

  /// Todo el progreso persistido, para reconciliar con el remoto (front#18).
  Future<List<LevelProgress>> getAll();

  /// Persiste el set de progreso ya reconciliado (front#18).
  Future<void> upsertAll(List<LevelProgress> progress);
}
