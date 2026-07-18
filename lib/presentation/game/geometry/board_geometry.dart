import 'package:flutter/widgets.dart';

import '../../../domain/game_core/space/board_space.dart';
import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'hex_geometry.dart';
import 'rect_geometry.dart';

/// Seam de presentación (front#126): centraliza la aritmética celda<->píxel que
/// antes cada superficie (painter de superficie, hit-test, flecha, salida)
/// inlineaba asumiendo celdas cuadradas. Polimórfico por geometría del espacio;
/// el ÚNICO punto de selección por tipo de la capa de presentación.
abstract class BoardGeometry {
  factory BoardGeometry.forSpace(BoardSpace space, BoxConstraints c) =>
      space is HexSpace ? HexGeometry(space, c) : RectGeometry(space, c);

  /// Tamaño del tablero en píxeles (alimenta BoardViewport).
  Size get size;

  /// Escalar de tamaño de celda para grosores de trazo. Rect: lado de celda.
  /// Hex: separación entre centros vecinos (= √3·s).
  double get cellSize;

  /// Centro de celda en coordenadas de tablero (origen = esquina del marco).
  Offset centerOf(Position p);

  /// Celda bajo el píxel [px], o null si cae fuera del tablero (o de un hueco
  /// enmascarado, en hex). Rect clampa a la caja; el hueco lo filtra el widget.
  Position? cellAt(Offset px);

  /// Celdas desde [head] en [dir] hasta la frontera, cercano→frontera, sin head.
  List<Position> exitLane(Position head, Direction dir);
}
