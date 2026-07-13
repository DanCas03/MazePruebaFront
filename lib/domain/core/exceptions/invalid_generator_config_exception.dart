import 'domain_exception.dart';

/// Se lanza cuando la configuración del flujo "Generar nivel" (front#36) viola
/// una invariante de dominio: dimensiones fuera del rango jugable de
/// [GeneratorConfig], o un GeneratedBoard construido sin seed efectiva. La UI
/// valida antes de llamar; esta es la última línea defensiva del dominio.
class InvalidGeneratorConfigException extends DomainException {
  const InvalidGeneratorConfigException(super.message);
}
