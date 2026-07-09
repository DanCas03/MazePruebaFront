/// Configuración de entorno. La URL base del back se inyecta en build-time con
/// --dart-define=API_BASE_URL=...; el default apunta al host desde el emulador
/// Android (10.0.2.2 = localhost del host). Único punto del valor (SRP).
class AppConfig {
  AppConfig._();
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
