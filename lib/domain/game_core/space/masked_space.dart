import '../value_objects/position.dart';
import 'rect_space.dart';

/// Espacio de PRODUCCIÓN con máscara arbitraria (Fase 1, #86): un marco
/// rectangular cols×rows cuyas celdas activas son un subconjunto arbitrario de
/// la caja ([activeCells]). Es el hermano de producción del doble test-only
/// [HoledRectSpace]: mismo patrón (extiende [RectSpace] para reusar el único
/// switch dirección→delta del artefacto en [RectSpace.step], ADR-0005 D2), pero
/// aquí `allCells`/`cellCount` SÍ reflejan la máscara — es geometría real, no
/// una certificación OCP.
///
/// Una celda enmascarada (fuera de [activeCells] aunque dentro de la caja) es
/// frontera: `step` que aterriza en ella devuelve null, exactamente igual que
/// un agujero de [HoledRectSpace] o el borde del tablero. Así
/// `exitLane`/`ArrowBoard.canExit` operan sobre cualquier silueta sin cambiar
/// una línea de consumidor (OCP).
///
/// Precondición: [activeCells] ⊆ caja cols×rows. Con ella, `cellCount`
/// (= tamaño del set) coincide con la cuenta de `allCells`, y `bounds`
/// (heredado de [RectSpace]) es la caja completa desde el origen.
class MaskedSpace extends RectSpace {
  final Set<Position> activeCells;

  const MaskedSpace(super.cols, super.rows, {required this.activeCells});

  @override
  bool contains(Position pos) =>
      super.contains(pos) && activeCells.contains(pos);

  @override
  int get cellCount => activeCells.length;

  @override
  Iterable<Position> get allCells sync* {
    // Recorre la caja en orden canónico row-major y filtra por la máscara:
    // así el orden es el del contrato y coincide exactamente con `contains`.
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final pos = Position(row: row, col: col);
        if (activeCells.contains(pos)) yield pos;
      }
    }
  }

  @override
  List<Object?> get props => [...super.props, activeCells];
}
