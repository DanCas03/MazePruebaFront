// AOP: cross-cutting concern de logging inyectado como puerto, no escrito en
// la logica de negocio. El dominio/aplicacion dependen de esta abstraccion
// (DIP) y nunca del package concreto.
abstract interface class ILoggerService {
  void log(String message, String context);
  void error(String message, String context, [Object? error]);
  void warn(String message, String context);
}
