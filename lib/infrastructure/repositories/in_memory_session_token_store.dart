import '../../domain/auth/repositories/i_session_token_store.dart';
import '../../domain/auth/value_objects/auth_token.dart';

/// Impl en memoria del token vivo de la sesión (front#16). No persiste nada: la
/// durabilidad entre reinicios la cubre IAuthTokenStorage cuando `persist` es
/// true. El composition root crea UNA instancia compartida por el interceptor y
/// el AuthController.
class InMemorySessionTokenStore implements ISessionTokenStore {
  AuthToken? _token;

  @override
  AuthToken? get current => _token;

  @override
  set current(AuthToken? token) => _token = token;
}
