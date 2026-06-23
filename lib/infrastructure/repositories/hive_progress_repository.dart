import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../data_sources/local/hive_level_progress_data_source.dart';

/// Adapter: implementa el puerto ILevelProgressRepository del dominio mapeando
/// los Value Objects (LevelId / MoveCount) a/desde el modelo Hive a través del
/// DataSource. Nunca toca Hive directamente, lo que cumple DIP y mantiene la
/// regla de dependencias (infraestructura -> dominio).
class HiveProgressRepository implements ILevelProgressRepository {
  final HiveLocalDataSource _dataSource;
  HiveProgressRepository(this._dataSource);

  @override
  Future<MoveCount?> getProgress(LevelId levelId) async {
    final model = _dataSource.getProgress(levelId.value);
    if (model == null) return null;
    return MoveCount(model.moveCount);
  }

  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) =>
      _dataSource.saveProgress(levelId.value, moves.value);

  @override
  Future<void> markCompleted(LevelId levelId) =>
      _dataSource.markCompleted(levelId.value);

  @override
  Future<bool> isCompleted(LevelId levelId) async =>
      _dataSource.isCompleted(levelId.value);
}
