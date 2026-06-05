// lib/domain/game_core/value_objects/position.dart

import 'direction.dart';

/// Value Object inmutable que representa una coordenada en la cuadrícula.
///
/// DDD: un Value Object se define por sus atributos, no por una identidad.
/// Por eso sobreescribimos `==` y `hashCode`: dos `Position(x:1, y:2)` deben
/// considerarse iguales aunque sean instancias distintas en memoria.
///
/// Nota de diseño: el constructor NO valida no-negatividad de forma
/// intencionada. El cálculo de movimiento genera posiciones objetivo
/// transitorias fuera de los bordes (p. ej. y = -1 al intentar salir por
/// arriba) que el `Board` descarta vía `getCellAt`. Validar aquí rompería ese
/// flujo legítimo.
class Position {
  final int x;
  final int y;

  const Position({required this.x, required this.y});

  /// Devuelve una NUEVA posición desplazada según la [direction] dada.
  ///
  /// Concentra la aritmética de movimiento en el dominio reutilizando el
  /// vector (`dx`, `dy`) que expone el Value Object [Direction]. Así los casos
  /// de uso no necesitan conocer cómo se traduce una dirección a coordenadas.
  Position translate(Direction direction) {
    return Position(x: x + direction.dx, y: y + direction.dy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Position(x: $x, y: $y)';
}
