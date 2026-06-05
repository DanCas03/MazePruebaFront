// lib/domain/game_core/value_objects/direction.dart

/// Value Object que representa las cuatro direcciones posibles del juego.
///
/// DDD: aunque Dart ya ofrece type-safety con `enum`, encapsulamos aquí
/// el comportamiento asociado a una dirección (rotación y vector de desplazamiento)
/// para eliminar la "primitive obsession": ninguna otra capa vuelve a escribir
/// un `switch` sobre la dirección para calcular giros o movimientos.
enum Direction { up, down, left, right }

/// Comportamiento del Value Object [Direction].
///
/// Se modela como `extension` para mantener el `enum` puro y, a la vez,
/// concentrar las reglas (rotación horaria y desplazamiento) en un único lugar
/// (DRY + Single Responsibility).
extension DirectionBehavior on Direction {
  /// Desplazamiento horizontal asociado a la dirección.
  ///
  /// El eje X crece hacia la derecha; por eso `left = -1` y `right = +1`.
  int get dx {
    switch (this) {
      case Direction.left:
        return -1;
      case Direction.right:
        return 1;
      case Direction.up:
      case Direction.down:
        return 0;
    }
  }

  /// Desplazamiento vertical asociado a la dirección.
  ///
  /// El eje Y crece hacia abajo (convención de matrices/pantalla); por eso
  /// `up = -1` y `down = +1`.
  int get dy {
    switch (this) {
      case Direction.up:
        return -1;
      case Direction.down:
        return 1;
      case Direction.left:
      case Direction.right:
        return 0;
    }
  }

  /// Devuelve la siguiente dirección al girar 90° en sentido horario.
  ///
  /// Ciclo: up → right → down → left → up.
  Direction get rotateClockwise {
    switch (this) {
      case Direction.up:
        return Direction.right;
      case Direction.right:
        return Direction.down;
      case Direction.down:
        return Direction.left;
      case Direction.left:
        return Direction.up;
    }
  }

  /// Número de cuartos de vuelta (en sentido horario) respecto a [Direction.up].
  ///
  /// Lo consume la capa de presentación para rotar el ícono de la flecha sin
  /// reimplementar la trigonometría en el widget.
  int get quarterTurns {
    switch (this) {
      case Direction.up:
        return 0;
      case Direction.right:
        return 1;
      case Direction.down:
        return 2;
      case Direction.left:
        return 3;
    }
  }

  /// Convierte un string crudo (proveniente de JSON) en una [Direction].
  ///
  /// Centraliza el parseo para que la infraestructura no contenga su propio
  /// `switch` de strings.
  static Direction fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'up':
        return Direction.up;
      case 'down':
        return Direction.down;
      case 'left':
        return Direction.left;
      case 'right':
        return Direction.right;
      default:
        return Direction.up;
    }
  }
}
