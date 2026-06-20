import 'package:equatable/equatable.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';

/// Flecha como CAMINO: `cells` va de la cola (first) a la cabeza (last), con
/// celdas ortogonalmente adyacentes y sin repetir. Una flecha recta es el caso
/// degenerado (sin curvas). `headDirection` es la dirección por la que la cabeza
/// abandona el tablero (mecánica "serpiente": el cuerpo se retrae por su propio
/// camino, así que la salida solo depende del carril recto frente a la cabeza).
class Arrow extends Equatable {
  final ArrowId id;
  final List<Position> cells;
  final Direction headDirection;

  const Arrow({
    required this.id,
    required this.cells,
    required this.headDirection,
  });

  /// Conveniencia para flechas rectas: genera `length` celdas desde `tail` en
  /// `direction`. Mantiene ergonómicos los call sites que no necesitan curvas.
  factory Arrow.straight({
    required ArrowId id,
    required Position tail,
    required Direction direction,
    required int length,
  }) {
    assert(length >= 1, 'length must be >= 1');
    final cells = List<Position>.generate(length, (i) => switch (direction) {
          Direction.right => Position(row: tail.row, col: tail.col + i),
          Direction.left => Position(row: tail.row, col: tail.col - i),
          Direction.down => Position(row: tail.row + i, col: tail.col),
          Direction.up => Position(row: tail.row - i, col: tail.col),
        });
    return Arrow(id: id, cells: cells, headDirection: direction);
  }

  Position get head => cells.last;
  Position get tail => cells.first;
  Direction get direction => headDirection; // compat para widgets/animaciones
  int get length => cells.length;

  /// Celdas libres que debe recorrer la cabeza para salir del tablero.
  List<Position> exitPath(int cols, int rows) {
    final h = head;
    return switch (headDirection) {
      Direction.right => List.generate(
          cols - 1 - h.col, (i) => Position(row: h.row, col: h.col + 1 + i)),
      Direction.left => List.generate(
          h.col, (i) => Position(row: h.row, col: h.col - 1 - i)),
      Direction.down => List.generate(
          rows - 1 - h.row, (i) => Position(row: h.row + 1 + i, col: h.col)),
      Direction.up => List.generate(
          h.row, (i) => Position(row: h.row - 1 - i, col: h.col)),
    };
  }

  @override
  List<Object?> get props => [id, cells, headDirection];
}
