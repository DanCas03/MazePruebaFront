import 'domain_exception.dart';

/// Se lanza cuando un [Level] viola una invariante de dominio (tablero sin
/// flechas, o timeLimitSec <= 0). El decoder de infraestructura la traduce a
/// FormatException y, de ahí, el repo a LevelCorrupted.
class InvalidLevelException extends DomainException {
  const InvalidLevelException(super.message);
}
