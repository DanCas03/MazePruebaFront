import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/repositories/i_auth_token_storage.dart';
import '../../domain/auth/value_objects/auth_token.dart';
import '../use_cases/restore_session_use_case.dart';
import 'auth_state.dart';

// Se compone en core/DI o se sobreescribe en tests; la fábrica por defecto
// falla explícitamente para no acoplar este archivo a impls concretas (DIP).
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(
  () => throw UnimplementedError(
    'authControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva (Riverpod) del lazo de auth. En el arranque restaura la
/// sesión (auto-login); front#15 llamará a [saveSession] tras un login exitoso
/// y a [signOut] al cerrar sesión.
class AuthController extends AsyncNotifier<AuthState> {
  final IAuthTokenStorage _storage;
  final RestoreSessionUseCase _restore;

  AuthController(this._storage, this._restore);

  @override
  Future<AuthState> build() => _restore.execute();

  /// Persiste el token (si [persist]) y marca la sesión como autenticada. La
  /// invoca front#15 tras un login/registro exitoso. Con [persist] `false`
  /// ("recordarme" desmarcado) la sesión vive solo en memoria: no se escribe en
  /// el almacenamiento, así que al reabrir la app no habrá auto-login.
  Future<void> saveSession(AuthToken token, {bool persist = true}) async {
    if (persist) {
      await _storage.save(token);
    }
    state = AsyncValue.data(Authenticated(token));
  }

  /// Cierra sesión: borra el token y vuelve a estado no autenticado.
  Future<void> signOut() async {
    await _storage.clear();
    state = AsyncValue.data(const Unauthenticated());
  }
}
