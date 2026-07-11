import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/repositories/i_auth_token_storage.dart';
import '../../domain/auth/repositories/i_session_token_store.dart';
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
/// sesión (auto-login); front#15 llama a [saveSession] tras un login exitoso y
/// a [signOut] al cerrar sesión. El token vivo se publica SIEMPRE en
/// [ISessionTokenStore] (memoria) para que el interceptor firme las llamadas
/// autenticadas también con `remember:false` (front#16).
class AuthController extends AsyncNotifier<AuthState> {
  final IAuthTokenStorage _storage;
  final RestoreSessionUseCase _restore;
  final ISessionTokenStore _session;

  AuthController(this._storage, this._restore, this._session);

  @override
  Future<AuthState> build() async {
    final state = await _restore.execute();
    // Publica el token restaurado en la sesión viva para el interceptor
    // (cubre `remember:true`: el token venía de storage).
    // El store en memoria refleja SIEMPRE la sesión real: si el restore no
    // autentica (token ausente/expirado), se limpia cualquier token previo para
    // no firmar requests con un token muerto si el notifier se re-invalida.
    if (state is Authenticated) {
      _session.current = state.token;
    } else {
      _session.current = null;
    }
    return state;
  }

  /// Marca la sesión como autenticada, publicando el token en la sesión viva
  /// (memoria) SIEMPRE. Con [persist] `true` ADEMÁS lo guarda en el
  /// almacenamiento seguro para el auto-login entre reinicios; con `false`
  /// ("recordarme" desmarcado) solo vive en memoria durante la sesión.
  Future<void> saveSession(AuthToken token, {bool persist = true}) async {
    _session.current = token;
    if (persist) {
      await _storage.save(token);
    }
    state = AsyncValue.data(Authenticated(token));
  }

  /// Cierra sesión: borra el token (memoria + storage) y vuelve a no autenticado.
  Future<void> signOut() async {
    _session.current = null;
    try {
      await _storage.clear();
    } finally {
      // El logout siempre deja sesión y estado coherentes aunque el borrado en
      // keychain falle; la excepción se propaga tras actualizar el estado.
      state = AsyncValue.data(const Unauthenticated());
    }
  }
}
