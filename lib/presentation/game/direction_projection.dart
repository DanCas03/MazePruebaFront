import 'dart:math' as math;
import 'dart:ui';

import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

/// Consolida la proyección dirección→pantalla que antes vivía duplicada en
/// ArrowPainter, SnakeExitPainter y ArrowWidget (ADR-0005 D4). Los
/// painters/widgets siguen recibiendo primitivas (cols/rows/Position),
/// nunca un BoardSpace: la proyección de render es un seam distinto del
/// dominio. Total sobre los 8 valores de [Direction] (ADR-0007 D2/D3).

/// Componente x del vector diagonal flat-top (sqrt(3)/2).
const double _flatTopX = 0.8660254037844386;

/// Vector unitario de [dir] en coordenadas de pantalla (x=col, y=row).
/// Diagonales con geometría flat-top: la punta se separa medio paso en y y
/// [_flatTopX] en x.
Offset directionUnit(Direction dir) => switch (dir) {
      Direction.right => const Offset(1, 0),
      Direction.left => const Offset(-1, 0),
      Direction.down => const Offset(0, 1),
      Direction.up => const Offset(0, -1),
      Direction.upRight => const Offset(_flatTopX, -0.5),
      Direction.downRight => const Offset(_flatTopX, 0.5),
      Direction.upLeft => const Offset(-_flatTopX, -0.5),
      Direction.downLeft => const Offset(-_flatTopX, 0.5),
    };

/// Ángulo en radianes de [dir], para rotar la cabeza de la flecha dibujada.
/// Rect mantiene sus valores exactos; las diagonales son coherentes con los
/// vectores de [directionUnit] (atan2(dy, dx)).
double directionAngle(Direction dir) => switch (dir) {
      Direction.right => 0.0,
      Direction.left => math.pi,
      Direction.down => math.pi / 2,
      Direction.up => -math.pi / 2,
      Direction.upRight => -math.pi / 6,
      Direction.downRight => math.pi / 6,
      Direction.upLeft => -5 * math.pi / 6,
      Direction.downLeft => 5 * math.pi / 6,
    };

/// Distancia en celdas desde [head] hasta la frontera del tablero cols×rows
/// siguiendo [dir]. Aritmética de presentación legítimamente 2D (ADR-0005
/// D4) — equivalente numérico a `RectSpace(cols, rows).exitLane(head, dir).length`.
/// La distancia diagonal (y toda la hexagonal) necesita el espacio, que este
/// seam deliberadamente no recibe: se resuelve en el render hexagonal
/// (front#126). Switch total, sin `default` que trague casos.
int cellsToEdge(Position head, Direction dir,
        {required int cols, required int rows}) =>
    switch (dir) {
      Direction.right => cols - 1 - head.col,
      Direction.left => head.col,
      Direction.down => rows - 1 - head.row,
      Direction.up => head.row,
      Direction.upLeft ||
      Direction.upRight ||
      Direction.downLeft ||
      Direction.downRight =>
        throw UnimplementedError(
            'cellsToEdge diagonal se resuelve en el render hexagonal (front#126)'),
    };
