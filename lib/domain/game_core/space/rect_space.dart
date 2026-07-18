import '../../core/exceptions/invalid_direction_exception.dart';
import '../value_objects/direction.dart';
import '../value_objects/position.dart';
import 'board_space.dart';
import 'bounding_box.dart';
import 'masked_space.dart';

/// Espacio rectangular cols×rows: la única geometría de producción hoy.
/// Contiene el único switch dirección→delta del artefacto (ADR-0005 D2),
/// dentro de [step], guardado por [contains] — nunca construye una [Position]
/// con coordenadas negativas (lanzaría InvalidPositionException).
class RectSpace extends BoardSpace {
  final int cols;
  final int rows;

  const RectSpace(this.cols, this.rows);

  // Orden idéntico a `Direction.values` pre-#124 (up, down, left, right): el
  // generador consume `space.directions` en este orden y su secuencia RNG debe
  // quedar byte-idéntica (front#124). NO usar `Direction.values` (ahora son 8).
  static const List<Direction> _rectDirections = [
    Direction.up,
    Direction.down,
    Direction.left,
    Direction.right,
  ];

  @override
  Iterable<Direction> get directions => _rectDirections;

  @override
  bool contains(Position pos) =>
      pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols;

  @override
  Position? step(Position pos, Direction dir) {
    // Fail-fast (ADR-0007 D3): una dirección ajena al espacio nunca devuelve
    // celda ni null silencioso.
    if (!_rectDirections.contains(dir)) {
      throw InvalidDirectionException(
          'Direction $dir no es válida en RectSpace (up, down, left, right)');
    }
    final (dr, dc) = switch (dir) {
      Direction.up => (-1, 0),
      Direction.down => (1, 0),
      Direction.left => (0, -1),
      Direction.right => (0, 1),
      Direction.upLeft ||
      Direction.upRight ||
      Direction.downLeft ||
      Direction.downRight =>
        throw InvalidDirectionException('unreachable: guarded above'),
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
  BoardSpace masked(Set<Position> activeCells) =>
      MaskedSpace(cols, rows, activeCells: activeCells);

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
