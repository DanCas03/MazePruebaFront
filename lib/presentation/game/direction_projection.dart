import 'dart:math' as math;
import 'dart:ui';

import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

/// Consolida la proyección dirección→pantalla que antes vivía duplicada en
/// ArrowPainter, SnakeExitPainter y ArrowWidget (ADR-0005 D4). Los
/// painters/widgets siguen recibiendo primitivas (cols/rows/Position),
/// nunca un BoardSpace: la proyección de render es un seam distinto del
/// dominio.

/// Vector unitario de [dir] en coordenadas de pantalla (x=col, y=row).
Offset directionUnit(Direction dir) => switch (dir) {
      Direction.right => const Offset(1, 0),
      Direction.left => const Offset(-1, 0),
      Direction.down => const Offset(0, 1),
      Direction.up => const Offset(0, -1),
    };

/// Ángulo en radianes de [dir], para rotar la cabeza de la flecha dibujada.
double directionAngle(Direction dir) => switch (dir) {
      Direction.right => 0.0,
      Direction.left => math.pi,
      Direction.down => math.pi / 2,
      Direction.up => -math.pi / 2,
    };

/// Distancia en celdas desde [head] hasta la frontera del tablero cols×rows
/// siguiendo [dir]. Aritmética de presentación legítimamente 2D (ADR-0005
/// D4: "painters siguen recibiendo primitivas") — equivalente numérico a
/// `RectSpace(cols, rows).exitLane(head, dir).length`.
int cellsToEdge(Position head, Direction dir,
        {required int cols, required int rows}) =>
    switch (dir) {
      Direction.right => cols - 1 - head.col,
      Direction.left => head.col,
      Direction.down => rows - 1 - head.row,
      Direction.up => head.row,
    };
