/// Fallos esperados del lazo de autenticación, como jerarquía sellada para que
/// la UI haga pattern matching exhaustivo y muestre `message` sin conocer
/// detalles de red/HTTP. Mensajes en ES (front#4 los externalizará).
sealed class AuthFailure {
  const AuthFailure();
  String get message;
}

class InvalidCredentials extends AuthFailure {
  const InvalidCredentials();
  @override
  String get message => 'Email o contraseña incorrectos';
}

class EmailAlreadyRegistered extends AuthFailure {
  const EmailAlreadyRegistered();
  @override
  String get message => 'Ese email ya está registrado';
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure();
  @override
  String get message => 'Sin conexión. Intenta de nuevo';
}

class UnexpectedFailure extends AuthFailure {
  const UnexpectedFailure();
  @override
  String get message => 'Algo salió mal. Intenta más tarde';
}
