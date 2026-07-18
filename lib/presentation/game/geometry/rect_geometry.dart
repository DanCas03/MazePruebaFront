import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../domain/game_core/space/board_space.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'board_geometry.dart';

/// Geometría rectangular: extrae, VERBATIM, las fórmulas que hoy viven inline en
/// BoardView/ArrowPainter/SnakeExitPainter. Byte-idéntico por construcción; los
/// tests rect existentes son el candado.
class RectGeometry implements BoardGeometry {
  final BoardSpace space;
  final BoundingBox _frame;
  final double _cell;

  RectGeometry(this.space, BoxConstraints c)
      : _frame = space.bounds,
        _cell = math.min(
          c.maxWidth / space.bounds.cols,
          c.maxHeight / space.bounds.rows,
        );

  @override
  Size get size => Size(_frame.cols * _cell, _frame.rows * _cell);

  @override
  double get cellSize => _cell;

  @override
  Offset centerOf(Position p) => Offset(
        (p.col - _frame.minCol + 0.5) * _cell,
        (p.row - _frame.minRow + 0.5) * _cell,
      );

  @override
  Position? cellAt(Offset px) => Position(
        row: ((px.dy / _cell).floor() + _frame.minRow)
            .clamp(_frame.minRow, _frame.maxRow),
        col: ((px.dx / _cell).floor() + _frame.minCol)
            .clamp(_frame.minCol, _frame.maxCol),
      );

  // No usado por la animación de salida rect (que conserva cellsToEdge para
  // preservar el bug masked-rect byte a byte, front#126 D2); presente por
  // completitud de la interfaz.
  @override
  List<Position> exitLane(Position head, Direction dir) =>
      space.exitLane(head, dir);
}
