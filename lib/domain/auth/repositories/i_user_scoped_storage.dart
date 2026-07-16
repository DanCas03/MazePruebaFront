/// Puerto (DIP) del almacenamiento local que sigue el alcance de la cuenta
/// activa. Resuelve el bug de progreso compartido entre cuentas: el progreso se
/// guardaba en una caja Hive global (sin usuario en la clave), así que una
/// cuenta nueva heredaba —y hasta subía al server— el progreso de la anterior.
///
/// El AuthController (única capa que conoce las transiciones de sesión) lo
/// dirige: [activate] al autenticarse (abre/re-apunta al almacén del usuario)
/// y [deactivate] al cerrar sesión (lo desliga). La impl concreta vive en
/// infraestructura (Hive) y las capas internas solo conocen esta abstracción.
///
/// Interfaz mínima y cohesiva (ISP): solo el ciclo de vida del alcance, no el
/// acceso a datos (eso es del repositorio de progreso).
abstract interface class IUserScopedStorage {
  /// Activa el almacén local de la cuenta [userId]. Idempotente para el mismo
  /// usuario. Debe completarse ANTES de leer/escribir progreso de esa cuenta.
  Future<void> activate(String userId);

  /// Desliga el almacén de la cuenta activa (logout). Tras esto no hay alcance
  /// activo hasta el próximo [activate].
  Future<void> deactivate();
}
