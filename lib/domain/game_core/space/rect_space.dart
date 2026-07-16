import '../value_objects/direction.dart';
import '../value_objects/position.dart';
import 'board_space.dart';
import 'bounding_box.dart';

/// Espacio rectangular cols×rows: la única geometría de producción hoy.
/// Contiene el único switch dirección→delta del artefacto (ADR-0005 D2),
/// dentro de [step], guardado por [contains] — nunca construye una [Position]
/// con coordenadas negativas (lanzaría InvalidPositionException).
class RectSpace extends BoardSpace {
  final int cols;
  final int rows;

  const RectSpace(this.cols, this.rows);

  @override
  Iterable<Direction> get directions => Direction.values;

  @override
  bool contains(Position pos) =>
      pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols;

  @override
  Position? step(Position pos, Direction dir) {
    final (dr, dc) = switch (dir) {
      Direction.up => (-1, 0),
      Direction.down => (1, 0),
      Direction.left => (0, -1),
      Direction.right => (0, 1),
    };
    final nextRow = pos.row + dr;
    final nextCol = pos.col + dc;
    if (nextRow < 0 || nextCol < 0) return null;
    final next = Position(row: nextRow, col: nextCol);
    return contains(next) ? next : null;
  }

  @override
  int get cellCount => cols * rows;

  // Caja conocida en O(1): el rectángulo completo desde el origen (#85).
  @override
  BoundingBox get bounds =>
      BoundingBox(minRow: 0, minCol: 0, rows: rows, cols: cols);

  @override
  Iterable<Position> get allCells sync* {
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        yield Position(row: row, col: col);
      }
    }
  }

  @override
  List<Object?> get props => [cols, rows];
}
