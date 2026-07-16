import 'package:hive_ce/hive.dart';

import '../../models/level_progress_hive_model.dart';
import '../../repositories/hive_progress_box_scope.dart';

/// Acceso raw a Hive para el progreso de niveles.
///
/// Patrón Petros Efthymiou: el DataSource encapsula el acceso directo a la
/// librería de persistencia (Hive). El Repository depende de esta clase y no
/// de Hive, lo que permite mockear el DataSource y testear el Repository de
/// forma aislada.
///
/// La caja concreta ya NO es global: la resuelve [HiveProgressBoxScope] según
/// la cuenta activa (`level_progress_<userId>`), de modo que cada usuario
/// lee/escribe su propia caja y el progreso no se comparte entre cuentas.
class HiveLocalDataSource {
  final HiveProgressBoxScope _scope;

  HiveLocalDataSource(this._scope);

  Box<LevelProgressHiveModel> get _box => _scope.box;

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

  List<LevelProgressHiveModel> getAllProgress() => _box.values.toList();

  /// Upsert del registro completo (incluye score/estrellas). Preserva
  /// moveCount previo si existe; usa 0 para registros nuevos (el sync no
  /// transporta moveCount, solo completado + best score/estrellas).
  Future<void> upsertProgress(
      String levelId, bool completed, int? bestScore, int? bestStars) async {
    final existing = _box.get(levelId);
    if (existing != null) {
      existing.completed = completed;
      existing.bestScore = bestScore;
      existing.bestStars = bestStars;
      await existing.save();
    } else {
      await _box.put(
        levelId,
        LevelProgressHiveModel(
          levelId: levelId,
          moveCount: 0,
          completed: completed,
          bestScore: bestScore,
          bestStars: bestStars,
        ),
      );
    }
  }
}
