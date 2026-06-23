import 'package:hive_ce/hive.dart';

import '../../models/level_progress_hive_model.dart';

/// Acceso raw a Hive para el progreso de niveles.
///
/// Patrón Petros Efthymiou: el DataSource encapsula el acceso directo a la
/// librería de persistencia (Hive). El Repository depende de esta clase y no
/// de Hive, lo que permite mockear el DataSource y testear el Repository de
/// forma aislada.
class HiveLocalDataSource {
  static const _boxName = 'level_progress';

  Box<LevelProgressHiveModel> get _box =>
      Hive.box<LevelProgressHiveModel>(_boxName);

  LevelProgressHiveModel? getProgress(String levelId) => _box.get(levelId);

  Future<void> saveProgress(String levelId, int moveCount) async {
    final existing = _box.get(levelId);
    if (existing != null) {
      existing.moveCount = moveCount;
      await existing.save();
    } else {
      await _box.put(
          levelId,
          LevelProgressHiveModel(
              levelId: levelId, moveCount: moveCount, completed: false));
    }
  }

  Future<void> markCompleted(String levelId) async {
    final existing = _box.get(levelId);
    if (existing != null) {
      existing.completed = true;
      await existing.save();
    } else {
      await _box.put(
          levelId,
          LevelProgressHiveModel(
              levelId: levelId, moveCount: 0, completed: true));
    }
  }

  bool isCompleted(String levelId) => _box.get(levelId)?.completed ?? false;
}
