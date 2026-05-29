// lib/domain/factories/cell_factory.dart
import '../entities/cell.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';
import '../entities/empty_cell.dart';
import '../entities/wall_cell.dart';
import '../entities/arrow_cell.dart';
import '../entities/exit_cell.dart';

class CellFactory {
  /// Crea una celda basándose en un identificador de tipo (string o enum).
  /// Útil cuando construyes el nivel desde un JSON (Patrón Builder).
  static ICell createCell({
    required String type,
    required Position position,
    Direction? initialDirection,
  }) {
    switch (type.toLowerCase()) {
      case 'empty':
        return EmptyCell(position: position);
      case 'wall':
        return WallCell(position: position);
      case 'arrow':
        // Si no se provee dirección, podemos lanzar un error o poner una por defecto
        return ArrowCell(
          position: position,
          currentDirection: initialDirection ?? Direction.up,
        );
      case 'exit':
        return ExitCell(position: position);
      default:
        throw ArgumentError('Tipo de celda desconocido: $type');
    }
  }
}