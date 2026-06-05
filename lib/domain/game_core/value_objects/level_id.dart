// lib/domain/game_core/value_objects/level_id.dart

/// Value Object que identifica un nivel del juego.
///
/// DDD: reemplaza el primitivo `int` en las firmas de repositorios, casos de
/// uso y navegación. Encapsula su invariante (debe ser un entero positivo) y
/// se compara por valor, evitando confundir un id de nivel con cualquier otro
/// número suelto del sistema.
class LevelId {
  final int value;

  const LevelId(this.value) : assert(value > 0, 'El id de nivel debe ser positivo');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LevelId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'LevelId($value)';
}
