import '../value_objects/level_id.dart';
import '../../game_core/value_objects/move_count.dart';

abstract interface class ILevelProgressRepository {
  Future<MoveCount?> getProgress(LevelId levelId);
  Future<void> saveProgress(LevelId levelId, MoveCount moves);
  Future<void> markCompleted(LevelId levelId);
  Future<bool> isCompleted(LevelId levelId);
}
