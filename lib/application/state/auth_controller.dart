import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth/repositories/i_auth_token_storage.dart';
import '../../domain/auth/repositories/i_session_token_store.dart';
import '../../domain/auth/repositories/i_user_scoped_storage.dart';
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
  final IUserScopedStorage _userScope;

  AuthController(
    this._storage,
    this._restore,
    this._session,
    this._userScope,
  );

  /// Namespace de reserva cuando el token no expone un `sub` decodificable
  /// (token opaco/malformado — no ocurre con los JWT del back). Evita un crash
  /// al leer progreso a costa de un alcance compartido solo en ese caso límite.
  static const _fallbackUserId = '_default';

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
      // Aísla el progreso local de esta cuenta ANTES de exponer el estado
      // Authenticated: el guard dispara el sync en cuanto lo observe, y debe
      // operar ya sobre la caja del usuario correcto (no la de otra cuenta).
      await _activateScope(state.token);
    } else {
      _session.current = null;
    }
    return state;
  }

  /// Activa el almacén local de la cuenta dueña de [token] (namespacing del
  /// progreso por `sub` del JWT). Ver [IUserScopedStorage].
  Future<void> _activateScope(AuthToken token) =>
      _userScope.activate(token.subject ?? _fallbackUserId);

  /// Marca la sesión como autenticada, publicando el token en la sesión viva
  /// (memoria) SIEMPRE. Con [persist] `true` ADEMÁS lo guarda en el
  /// almacenamiento seguro para el auto-login entre reinicios; con `false`
  /// ("recordarme" desmarcado) solo vive en memoria durante la sesión.
  Future<void> saveSession(AuthToken token, {bool persist = true}) async {
    _session.current = token;
    if (persist) {
      await _storage.save(token);
    }
    // Aísla el progreso de esta cuenta antes de emitir Authenticated, para que
    // el sync disparado por el guard use ya la caja del usuario correcto.
    await _activateScope(token);
    state = AsyncValue.data(Authenticated(token));
  }

  /// Cierra sesión: borra el token (memoria + storage), desliga el almacén local
  /// de la cuenta y vuelve a no autenticado.
  Future<void> signOut() async {
    _session.current = null;
    // Desliga la caja de progreso de la cuenta saliente para que la siguiente
    // sesión arranque limpia. El cierre no debe bloquear el logout si falla.
    try {
      await _userScope.deactivate();
    } catch (_) {
      // Ignorado a propósito: un fallo al cerrar la caja no puede impedir salir.
    }
    try {
      await _storage.clear();
    } finally {
      // El logout siempre deja sesión y estado coherentes aunque el borrado en
      // keychain falle; la excepción se propaga tras actualizar el estado.
      state = AsyncValue.data(const Unauthenticated());
    }
  }
}
