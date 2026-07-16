import 'package:hive_ce/hive.dart';

import '../../domain/auth/repositories/i_user_scoped_storage.dart';
import '../models/level_progress_hive_model.dart';

/// Alcance por-cuenta de la caja Hive de progreso. Mantiene abierta la caja
/// `level_progress_<userId>` de la cuenta activa y la expone al DataSource, de
/// modo que cada cuenta lee/escribe SU propia caja (aislamiento por cuenta).
///
/// Cumple dos roles cohesivos alrededor de una sola responsabilidad —el ciclo
/// de vida de la caja activa—:
///  - implementa [IUserScopedStorage], que dirige el AuthController en cada
///    transición de sesión (activate al autenticar, deactivate al cerrar);
///  - sirve de registro de la caja activa para `HiveLocalDataSource`.
/// Ambos colaboradores viven en infraestructura, así que el DataSource puede
/// depender de esta clase concreta sin romper la regla de dependencias.
class HiveProgressBoxScope implements IUserScopedStorage {
  static const _prefix = 'level_progress_';

  Box<LevelProgressHiveModel>? _active;

  /// Nombre de la caja Hive namespaced para [userId] (usado también por DI/test).
  static String boxNameFor(String userId) => '$_prefix$userId';

  /// Caja de progreso de la cuenta activa. Lanza [StateError] si no hay alcance
  /// activo: el progreso solo se toca autenticado y [activate] corre antes de
  /// emitir el estado `Authenticated`, así que esto solo saltaría por un bug de
  /// orquestación (fail-fast en vez de leer/escribir la caja equivocada).
  Box<LevelProgressHiveModel> get box {
    final active = _active;
    if (active == null) {
      throw StateError(
        'No hay alcance de progreso activo: activate(userId) debe llamarse al autenticar',
      );
    }
    return active;
  }

  @override
  Future<void> activate(String userId) async {
    final name = boxNameFor(userId);
    final active = _active;
    // Idempotente: ya apunta a la caja de esta cuenta.
    if (active != null && active.isOpen && active.name == name) return;
    // Cambio de cuenta sin logout previo: cierra el alcance anterior.
    if (active != null && active.isOpen && active.name != name) {
      await active.close();
    }
    _active = Hive.isBoxOpen(name)
        ? Hive.box<LevelProgressHiveModel>(name)
        : await Hive.openBox<LevelProgressHiveModel>(name);
  }

  @override
  Future<void> deactivate() async {
    final active = _active;
    _active = null;
    if (active != null && active.isOpen) {
      await active.close();
    }
  }
}
