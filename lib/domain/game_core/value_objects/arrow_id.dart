// lib/domain/game_core/value_objects/arrow_id.dart

/// Value Object que identifica de forma única una flecha dentro de un tablero.
///
/// DDD: evita usar un `int`/`String` suelto como identificador y permite
/// comparar flechas por identidad lógica (no por referencia de memoria).
class ArrowId {
  final int value;

  const ArrowId(this.value) : assert(value >= 0, 'El id de flecha no puede ser negativo');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ArrowId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ArrowId($value)';
}
