import 'package:equatable/equatable.dart';

import '../value_objects/position.dart';

/// Caja envolvente rectangular de un [BoardSpace] (Fase 1, #85): la ventana
/// row-major mínima que se declara como marco del espacio. Deja que la
/// presentación derive el layout (tamaño de la grilla, offset) SIN asumir que
/// el espacio sea rectangular ni que arranque en el origen — la geometría real
/// la sigue decidiendo `BoardSpace.contains`/`allCells`. Un espacio vacío tiene
/// caja 0×0 ([isEmpty]).
class BoundingBox extends Equatable {
  final int minRow;
  final int minCol;
  final int rows; // alto de la caja en celdas
  final int cols; // ancho de la caja en celdas

  const BoundingBox({
    required this.minRow,
    required this.minCol,
    required this.rows,
    required this.cols,
  });

  /// Última fila/columna incluida en la caja (inclusive). Sin sentido si vacía.
  int get maxRow => minRow + rows - 1;
  int get maxCol => minCol + cols - 1;

  bool get isEmpty => rows == 0 || cols == 0;

  /// True si [pos] cae dentro del marco (no dice si la celda EXISTE en el
  /// espacio — eso lo responde `BoardSpace.contains`).
  bool contains(Position pos) =>
      !isEmpty &&
      pos.row >= minRow &&
      pos.row <= maxRow &&
      pos.col >= minCol &&
      pos.col <= maxCol;

  @override
  List<Object?> get props => [minRow, minCol, rows, cols];
}
