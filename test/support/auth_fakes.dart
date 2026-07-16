import 'package:flutter_arrow_maze/domain/auth/repositories/i_user_scoped_storage.dart';

/// No-op del alcance por-cuenta para tests que ejercitan el AuthController sin
/// tocar Hive (usan un repo de progreso falso). El aislamiento real por cuenta
/// se cubre en `hive_progress_box_scope_test.dart`.
class NoopUserScopedStorage implements IUserScopedStorage {
  @override
  Future<void> activate(String userId) async {}

  @override
  Future<void> deactivate() async {}
}
