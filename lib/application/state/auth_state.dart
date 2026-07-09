import '../../domain/auth/value_objects/auth_token.dart';

// State Pattern (sealed): estados mutuamente excluyentes del lazo de auth, para
// que la UI (front#15: guard de ruta) haga pattern matching exhaustivo sin
// flags booleanos. front#14 sólo produce estos estados; el guard los consume.
sealed class AuthState {
  const AuthState();
}

/// Sesión restaurada y vigente: portamos el token para el interceptor Dio
/// (front#15) y para las llamadas autenticadas.
class Authenticated extends AuthState {
  final AuthToken token;
  const Authenticated(this.token);
}

/// No hay sesión (nunca hubo, se cerró, o el token estaba caducado).
class Unauthenticated extends AuthState {
  const Unauthenticated();
}
