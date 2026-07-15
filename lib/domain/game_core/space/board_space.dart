import 'package:equatable/equatable.dart';

import '../value_objects/direction.dart';
import '../value_objects/position.dart';
import 'bounding_box.dart';

/// Geometría del tablero como concepto propio (ADR-0005 D1/D2): qué celdas
/// existen, cuáles son adyacentes, qué es un carril recto y dónde está la
/// frontera por la que una flecha sale. Único intérprete de [Direction] junto
/// con sus implementaciones concretas — nadie más hace aritmética dr/dc.
abstract class BoardSpace extends Equatable {
  const BoardSpace();

  /// Direcciones válidas en este espacio.
  Iterable<Direction> get directions;

  /// True si [pos] pertenece al espacio.
  bool contains(Position pos);

  /// Celda vecina de [pos] en [dir], o null si cae fuera del espacio.
  Position? step(Position pos, Direction dir);

  /// Cantidad total de celdas del espacio.
  int get cellCount;

  /// Todas las celdas del espacio, en orden canónico row-major (row asc,
  /// luego col asc) — contrato del módulo, no un detalle de implementación.
  Iterable<Position> get allCells;

  /// Caja envolvente del espacio (Fase 1, #85): el marco rectangular que la
  /// presentación usa para dimensionar la grilla, sin asumir forma. Default
  /// GENÉRICO: derivado en O(cellCount) del min/max de [allCells] — funciona
  /// para cualquier geometría. Los espacios con dimensiones conocidas
  /// (p. ej. RectSpace) lo sobreescriben en O(1). Vacío ⇒ caja 0×0.
  BoundingBox get bounds {
    final iterator = allCells.iterator;
    if (!iterator.moveNext()) {
      return const BoundingBox(minRow: 0, minCol: 0, rows: 0, cols: 0);
    }
    var minRow = iterator.current.row, maxRow = iterator.current.row;
    var minCol = iterator.current.col, maxCol = iterator.current.col;
    while (iterator.moveNext()) {
      final p = iterator.current;
      if (p.row < minRow) minRow = p.row;
      if (p.row > maxRow) maxRow = p.row;
      if (p.col < minCol) minCol = p.col;
      if (p.col > maxCol) maxCol = p.col;
    }
    return BoundingBox(
      minRow: minRow,
      minCol: minCol,
      rows: maxRow - minRow + 1,
      cols: maxCol - minCol + 1,
    );
  }

  /// True si existe una dirección que lleva de [a] a [b] en un paso.
  bool areAdjacent(Position a, Position b) {
    for (final dir in directions) {
      if (step(a, dir) == b) return true;
    }
    return false;
  }

  /// Celdas que hay que recorrer desde [head] en [dir] hasta la frontera del
  /// espacio, en orden cercano→frontera. Excluye [head].
  List<Position> exitLane(Position head, Direction dir) {
    final lane = <Position>[];
    var current = step(head, dir);
    while (current != null) {
      lane.add(current);
      current = step(current, dir);
    }
    return lane;
  }
}
