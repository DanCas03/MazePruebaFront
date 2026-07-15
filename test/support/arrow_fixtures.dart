import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Fixture de test: flecha recta de `length` celdas desde `tail` en
/// `direction`. Reemplaza al antiguo `Arrow.straight` (ADR-0005 D6: Arrow es
/// dato puro en producción; esta conveniencia solo tenía consumidores en
/// test/, así que se muda aquí en vez de recibir un BoardSpace — no hay
/// ningún llamador de producción que perder).
Arrow straightArrow({
  required ArrowId id,
  required Position tail,
  required Direction direction,
  required int length,
  String? paintRole,
}) {
  assert(length >= 1, 'length must be >= 1');
  final cells = List<Position>.generate(length, (i) => switch (direction) {
        Direction.right => Position(row: tail.row, col: tail.col + i),
        Direction.left => Position(row: tail.row, col: tail.col - i),
        Direction.down => Position(row: tail.row + i, col: tail.col),
        Direction.up => Position(row: tail.row - i, col: tail.col),
      });
  return Arrow(id: id, cells: cells, headDirection: direction, paintRole: paintRole);
}
