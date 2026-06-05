// lib/domain/game_core/value_objects/arrow_length.dart

/// Value Object que representa el tamaño de una flecha en número de celdas.
///
/// DDD: encapsula el invariante (una flecha ocupa al menos 1 celda) y evita el
/// primitive obsession con `int` en la entidad [Arrow] y en el generador.
class ArrowLength {
  final int value;

  const ArrowLength(this.value)
      : assert(value >= 1, 'Una flecha debe ocupar al menos una celda');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ArrowLength && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ArrowLength($value)';
}
