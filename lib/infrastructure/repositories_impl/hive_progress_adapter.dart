// lib/infrastructure/repositories_impl/hive_progress_adapter.dart

import 'package:hive_ce/hive.dart';

import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/entities/level_progress_entry.dart';
import '../../domain/game_core/value_objects/level_id.dart';
import '../models/level_progress_hive_model.dart';

/// Adaptador de persistencia que implementa [ILevelProgressRepository] sobre
/// Hive.
///
/// Patrón Adapter + DIP: el dominio define el puerto [ILevelProgressRepository]
/// (target) y esta clase adapta la API de la `Box` de Hive (adaptee) para
/// cumplirlo. Como el dominio depende de la interfaz y no de esta clase, se
/// invierte la dependencia: la infraestructura apunta al dominio, nunca al
/// revés. El `Box` se recibe ya abierto por constructor (su ciclo de vida lo
/// gestiona la composición de la app, no este adaptador).
class HiveProgressAdapter implements ILevelProgressRepository {
  final Box<LevelProgressHiveModel> _box;

  HiveProgressAdapter(this._box);

  @override
  Future<LevelProgressEntry?> loadProgress(LevelId levelId) async {
    final model = _box.get(_keyFor(levelId));
    return model?.toEntry();
  }

  @override
  Future<void> saveProgress(LevelProgressEntry entry) async {
    final model = LevelProgressHiveModel.fromEntry(entry);
    await _box.put(_keyFor(entry.levelId), model);
  }

  @override
  Future<List<LevelProgressEntry>> loadAllProgress() async {
    return _box.values.map((model) => model.toEntry()).toList();
  }

  /// La clave del box se deriva del Value Object, no de un primitivo suelto.
  String _keyFor(LevelId levelId) => levelId.value.toString();
}
