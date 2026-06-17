import 'domain_exception.dart';

// Señala un movimiento legítimo pero inválido en el estado actual del juego:
// la flecha existe en el tablero pero su recorrido de salida está bloqueado.
// Distinto de ArrowNotFoundException (id ausente = error de programación).
class InvalidMoveException extends DomainException {
  const InvalidMoveException(super.message);
}
