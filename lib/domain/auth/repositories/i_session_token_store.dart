import '../value_objects/auth_token.dart';

/// Puerto (DIP) de la fuente ÚNICA del token vivo de la sesión, en memoria.
///
/// Resuelve el gap de front#15: el token debe estar SIEMPRE disponible para el
/// interceptor durante la sesión (también con `remember:false`, que no escribe
/// en el almacenamiento persistente). `persist` (en AuthController) solo decide
/// si ADEMÁS se guarda en keychain para el auto-login entre reinicios. Interfaz
/// mínima y cohesiva (ISP): solo lo que el interceptor y el AuthController usan.
abstract interface class ISessionTokenStore {
  /// Token vivo de la sesión, o `null` si no hay sesión activa.
  AuthToken? get current;

  /// Fija (login) o borra (`null` = logout) el token vivo.
  set current(AuthToken? token);
}
