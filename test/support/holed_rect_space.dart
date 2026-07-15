import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Doble de certificación (ADR-0005 D2/D7, test-only): un RectSpace con
/// celdas removidas. El carril hereda de RectSpace y termina en el agujero
/// — el agujero es frontera, igual que el borde del tablero. Sobreescribe
/// SOLO `contains` (regla del ADR: un segundo adapter real, sin tocar nada
/// más). `allCells`/`cellCount` deliberadamente NO restan los agujeros: esto
/// no es una implementación de producción, es la prueba de que el resto del
/// dominio funciona sobre cualquier BoardSpace sin cambios (OCP).
class HoledRectSpace extends RectSpace {
  final Set<Position> holes;

  const HoledRectSpace(super.cols, super.rows, {required this.holes});

  @override
  bool contains(Position pos) => super.contains(pos) && !holes.contains(pos);

  @override
  List<Object?> get props => [...super.props, holes];
}
