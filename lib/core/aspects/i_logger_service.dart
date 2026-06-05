// lib/core/aspects/i_logger_service.dart

/// Puerto de logging (AOP).
///
/// DIP: la aplicación depende de esta abstracción, no del paquete concreto
/// `logger`. Así el logging —un cross-cutting concern— queda desacoplado de la
/// librería específica y puede sustituirse (consola, archivo, remoto) sin tocar
/// la lógica de negocio.
abstract class ILoggerService {
  void log(String message, {String? tag});
  void warn(String message, {String? tag});
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace});
}
