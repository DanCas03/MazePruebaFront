import 'package:equatable/equatable.dart';
import '../value_objects/arrow_id.dart';
import '../value_objects/arrow_length.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';

class Arrow extends Equatable {
  final ArrowId id;
  final Position tail;
  final Direction direction;
  final ArrowLength length;

  const Arrow({
    required this.id,
    required this.tail,
    required this.direction,
    required this.length,
  });

  Position get head {
    final n = length.value - 1;
    return switch (direction) {
      Direction.right => Position(row: tail.row, col: tail.col + n),
      Direction.left  => Position(row: tail.row, col: tail.col - n),
      Direction.down  => Position(row: tail.row + n, col: tail.col),
      Direction.up    => Position(row: tail.row - n, col: tail.col),
    };
  }

  List<Position> get cells {
    return List.generate(length.value, (i) => switch (direction) {
      Direction.right => Position(row: tail.row, col: tail.col + i),
      Direction.left  => Position(row: tail.row, col: tail.col - i),
      Direction.down  => Position(row: tail.row + i, col: tail.col),
      Direction.up    => Position(row: tail.row - i, col: tail.col),
    });
  }

  /// Celdas libres que debe recorrer la flecha para salir del tablero.
  List<Position> exitPath(int cols, int rows) {
    final h = head;
    return switch (direction) {
      Direction.right => List.generate(
          cols - 1 - h.col, (i) => Position(row: h.row, col: h.col + 1 + i)),
      Direction.left  => List.generate(
          h.col, (i) => Position(row: h.row, col: h.col - 1 - i)),
      Direction.down  => List.generate(
          rows - 1 - h.row, (i) => Position(row: h.row + 1 + i, col: h.col)),
      Direction.up    => List.generate(
          h.row, (i) => Position(row: h.row - 1 - i, col: h.col)),
    };
  }

  @override
  List<Object?> get props => [id, tail, direction, length];
}
