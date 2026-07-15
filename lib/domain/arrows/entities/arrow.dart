import 'package:equatable/equatable.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';

/// Flecha como CAMINO: `cells` va de la cola (first) a la cabeza (last), con
/// celdas ortogonalmente adyacentes y sin repetir. Una flecha recta es el caso
/// degenerado (sin curvas). `headDirection` es la dirección por la que la cabeza
/// abandona el tablero (mecánica "serpiente": el cuerpo se retrae por su propio
/// camino, así que la salida solo depende del carril recto frente a la cabeza).
///
/// Dato puro (ADR-0005 D2/D6): no conoce el espacio del tablero. El carril de
/// salida es responsabilidad de `BoardSpace.exitLane` (ver
/// `ArrowBoard.canExit`); construir una flecha recta para tests es
/// responsabilidad de `straightArrow` en `test/support/arrow_fixtures.dart`
/// (el único llamador de la antigua `Arrow.straight` era el propio código de
/// test — la producción nunca la usó).
class Arrow extends Equatable {
  final ArrowId id;
  final List<Position> cells;
  final Direction headDirection;

  /// Rol de pintado (Instrucciones de pintado, ADR 0004): dato OPACO servido por
  /// niveles temáticos que asocia esta flecha a un color de la `palette` del
  /// `Level`. Nulo en campaña. No participa en la mecánica (salida/solubilidad);
  /// solo lo consume el seam de color en presentación (front#67).
  final String? paintRole;

  const Arrow({
    required this.id,
    required this.cells,
    required this.headDirection,
    this.paintRole,
  });

  Position get head => cells.last;
  Position get tail => cells.first;
  Direction get direction => headDirection; // compat para widgets/animaciones
  int get length => cells.length;

  @override
  List<Object?> get props => [id, cells, headDirection, paintRole];
}
