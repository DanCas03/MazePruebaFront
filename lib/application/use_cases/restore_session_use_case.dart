import '../../domain/auth/repositories/i_auth_token_storage.dart';
import '../state/auth_state.dart';

/// Caso de uso del auto-login: al arrancar, decide si hay una sesión que
/// restaurar. Depende del puerto IAuthTokenStorage (DIP), lo que lo hace
/// testeable de forma aislada con un storage mockeado.
class RestoreSessionUseCase {
  final IAuthTokenStorage _storage;
  RestoreSessionUseCase(this._storage);

  Future<AuthState> execute({DateTime? now}) async {
    final token = await _storage.read();
    if (token == null) return const Unauthenticated();

    // Token caducado: lo purgamos para no reintentar en cada arranque y
    // exigimos re-login (evita auto-loguear hacia un 401 seguro).
    if (token.isExpired(now: now)) {
      await _storage.clear();
      return const Unauthenticated();
    }

    return Authenticated(token);
  }
}
