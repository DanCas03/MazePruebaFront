// lib/domain/game_core/value_objects/move_count.dart

/// Value Object que cuenta los movimientos realizados en un nivel.
///
/// DDD: sustituye el `int` suelto que se usaba para puntuación/progreso. Es
/// inmutable: `increment()` devuelve una nueva instancia en lugar de mutar el
/// estado, lo que evita efectos colaterales accidentales.
class MoveCount {
  final int value;

  const MoveCount(this.value)
      : assert(value >= 0, 'El número de movimientos no puede ser negativo');

  /// Punto de partida de un nivel recién cargado.
  const MoveCount.zero() : value = 0;

  /// Devuelve un nuevo [MoveCount] con un movimiento más.
  MoveCount increment() => MoveCount(value + 1);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MoveCount && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'MoveCount($value)';
}
