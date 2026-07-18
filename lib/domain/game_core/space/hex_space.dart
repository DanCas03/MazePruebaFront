import '../../core/exceptions/invalid_direction_exception.dart';
import '../value_objects/direction.dart';
import '../value_objects/position.dart';
import 'board_space.dart';
import 'bounding_box.dart';
import 'hex_masked_space.dart';

/// Malla hexagonal flat-top de radio [radius] (ADR-0007 D1), gemelo del back en
/// nombres y convención axial. Coordenadas axiales `(q, r)` mapeadas al
/// `Position(row, col)` existente SIN tocar el VO: `col = q + R`, `row = r + R`
/// (así ambas quedan >= 0 dentro del hex, respetando la invariante de Position).
/// Único intérprete de las 6 direcciones hex junto con [step] — nadie más hace
/// aritmética de deltas.
class HexSpace extends BoardSpace {
  final int radius;

  const HexSpace(this.radius) : assert(radius >= 1, 'radius must be >= 1');

  // Las 6 direcciones de un hex flat-top: up/down + las 4 diagonales. NO
  // incluye left/right (ADR-0007 D2).
  static const List<Direction> _hexDirections = [
    Direction.up,
    Direction.down,
    Direction.upRight,
    Direction.downRight,
    Direction.upLeft,
    Direction.downLeft,
  ];

  @override
  Iterable<Direction> get directions => _hexDirections;

  @override
  bool contains(Position pos) {
    final q = pos.col - radius;
    final r = pos.row - radius;
    return q.abs() <= radius &&
        r.abs() <= radius &&
        (q + r).abs() <= radius;
  }

  @override
  Position? step(Position pos, Direction dir) {
    // Fail-fast (ADR-0007 D3): guard explícito al inicio para left/right.
    if (!_hexDirections.contains(dir)) {
      throw InvalidDirectionException(
          'Direction $dir no es válida en HexSpace (up, down y las 4 diagonales)');
    }
    final (dr, dc) = switch (dir) {
      Direction.up => (-1, 0),
      Direction.down => (1, 0),
      Direction.upRight => (-1, 1),
      Direction.downRight => (0, 1),
      Direction.upLeft => (0, -1),
      Direction.downLeft => (1, -1),
      Direction.left || Direction.right =>
        throw InvalidDirectionException('unreachable: guarded above'),
    };
    final nextRow = pos.row + dr;
    final nextCol = pos.col + dc;
    // Guard de negativo antes de construir Position (que lanzaría con < 0):
    // pisar hacia afuera desde el borde es "cae fuera del espacio" => null.
    if (nextRow < 0 || nextCol < 0) return null;
    final next = Position(row: nextRow, col: nextCol);
    return contains(next) ? next : null;
  }

  @override
  int get cellCount => 3 * radius * radius + 3 * radius + 1;

  // Caja conocida en O(1): el hex de radio R cabe en un cuadrado (2R+1)²
  // (r y q recorren [-R, R] => row y col recorren [0, 2R]).
  @override
  BoundingBox get bounds => BoundingBox(
        minRow: 0,
        minCol: 0,
        rows: 2 * radius + 1,
        cols: 2 * radius + 1,
      );

  @override
  BoardSpace masked(Set<Position> activeCells) =>
      HexMaskedSpace(radius, activeCells: activeCells);

  @override
  Iterable<Position> get allCells sync* {
    final side = 2 * radius + 1;
    for (var row = 0; row < side; row++) {
      for (var col = 0; col < side; col++) {
        final pos = Position(row: row, col: col);
        if (contains(pos)) yield pos;
      }
    }
  }

  @override
  List<Object?> get props => [radius];
}
