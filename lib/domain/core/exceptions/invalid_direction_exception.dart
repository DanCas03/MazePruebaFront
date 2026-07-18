import 'domain_exception.dart';

/// Una dirección que no pertenece al espacio del tablero (ADR-0007 D3): p. ej.
/// una diagonal en [RectSpace] o `left`/`right` en [HexSpace]. `step` la lanza
/// en vez de devolver celda o `null` silencioso; la invariante de agregado la
/// lanza si una flecha declara un `headDirection` ajeno a `space.directions`.
class InvalidDirectionException extends DomainException {
  const InvalidDirectionException(super.message);
}
