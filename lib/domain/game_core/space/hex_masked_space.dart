import '../value_objects/position.dart';
import 'hex_space.dart';

/// Gemelo enmascarado de [HexSpace] (ADR-0007 D5): un hex de radio `R` cuyas
/// celdas activas son un subconjunto arbitrario ([activeCells]) — la silueta
/// temática sobre malla hexagonal. Espejo del patrón [MaskedSpace] sobre
/// [RectSpace]: extiende [HexSpace] para reusar el único intérprete de las 6
/// direcciones ([HexSpace.step]), pero aquí `allCells`/`cellCount` SÍ reflejan
/// la máscara. NO es un decorador.
///
/// Una celda enmascarada (fuera de [activeCells] aunque dentro del hexágono) es
/// frontera: `step` que aterriza en ella devuelve null vía [contains], igual que
/// el borde — así `exitLane`/`ArrowBoard.canExit` operan sobre cualquier silueta
/// hexagonal sin cambiar una línea de consumidor (OCP).
///
/// Precondición (documentada, no validada — constructor `const`, igual que
/// [MaskedSpace]): `activeCells ⊆` hexágono de radio [radius].
class HexMaskedSpace extends HexSpace {
  final Set<Position> activeCells;

  const HexMaskedSpace(super.radius, {required this.activeCells});

  @override
  bool contains(Position pos) =>
      super.contains(pos) && activeCells.contains(pos);

  @override
  int get cellCount => activeCells.length;

  @override
  Iterable<Position> get allCells sync* {
    // Recorre la caja del hex en orden canónico row-major y filtra por
    // `contains` (super.contains && activeCells) — orden del contrato preservado.
    final side = 2 * radius + 1;
    for (var row = 0; row < side; row++) {
      for (var col = 0; col < side; col++) {
        final pos = Position(row: row, col: col);
        if (contains(pos)) yield pos;
      }
    }
  }

  @override
  List<Object?> get props => [...super.props, activeCells];
}
