import '../value_objects/auth_token.dart';

/// Puerto (DIP) para la persistencia del token de sesión.
///
/// El dominio expone el contrato; la infraestructura decide el mecanismo
/// concreto (Keychain/Keystore vía flutter_secure_storage). Mantener la
/// interfaz pequeña y cohesiva (ISP): solo lo que el lazo de auth necesita.
abstract interface class IAuthTokenStorage {
  /// Persiste el token de forma segura, sobrescribiendo el anterior.
  Future<void> save(AuthToken token);

  /// Devuelve el token almacenado, o `null` si no hay sesión guardada.
  Future<AuthToken?> read();

  /// Borra el token almacenado (logout / token expirado).
  Future<void> clear();
}
