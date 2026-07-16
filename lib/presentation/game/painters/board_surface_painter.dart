import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../domain/game_core/space/board_space.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/position.dart';

/// Superficie del tablero consciente del espacio (Fase 1, front#87): pinta
/// panel y rejilla A TRAVÉS de [BoardSpace] en vez de asumir un rectángulo
/// cols×rows (reemplaza al par DecoratedBox + _GridPainter de BoardView).
///
/// Dos caminos:
///  - Caja llena (cada celda del bounding box existe — p. ej. RectSpace):
///    panel redondeado único + líneas de rejilla, píxel-idéntico al render
///    previo a #87. Es la garantía de regresión de la campaña.
///  - Espacio enmascarado: solo se rellenan las celdas que EXISTEN y cada
///    segmento de rejilla se dibuja únicamente entre dos celdas existentes
///    (una arista con celda ausente es frontera visual, como el borde).
///
/// La existencia se decide celda a celda con `contains` — NUNCA con
/// `allCells`/`cellCount`: el doble de certificación HoledRectSpace
/// deliberadamente no resta sus agujeros de esos miembros (ver test/support),
/// así que discriminar por conteo tomaría el camino equivocado.
///
/// El canvas está en coordenadas del MARCO (origen = esquina del bounding
/// box): la celda absoluta (row,col) se pinta en
/// ((col−minCol)·cell, (row−minRow)·cell). [visibleRect] (culling front#66)
/// llega en esas mismas coordenadas.
class BoardSurfacePainter extends CustomPainter {
  final BoardSpace space;
  final double cell;
  final Color surfaceColor;
  final Color gridColor;
  final Rect? visibleRect;

  const BoardSurfacePainter({
    required this.space,
    required this.cell,
    required this.surfaceColor,
    required this.gridColor,
    this.visibleRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frame = space.bounds;
    if (frame.isEmpty) return;
    if (_isFullBox(frame)) {
      _paintFullPanel(canvas, size, frame.cols, frame.rows);
    } else {
      _paintMaskedCells(canvas, frame);
    }
  }

  /// True si CADA celda del bounding box existe en el espacio. O(área de la
  /// caja) con `contains` O(1); a 50×50 son 2 500 chequeos por frame,
  /// despreciable frente al propio dibujo.
  bool _isFullBox(BoundingBox frame) {
    for (var r = 0; r < frame.rows; r++) {
      for (var c = 0; c < frame.cols; c++) {
        if (!space.contains(
            Position(row: frame.minRow + r, col: frame.minCol + c))) {
          return false;
        }
      }
    }
    return true;
  }

  /// Camino de caja llena: reproduce EXACTAMENTE el render previo a #87
  /// (DecoratedBox redondeado + _GridPainter con culling) para que la
  /// campaña rectangular no cambie ni un píxel.
  void _paintFullPanel(Canvas canvas, Size size, int cols, int rows) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.35)),
      Paint()..color = surfaceColor,
    );

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final cw = size.width / cols;
    final ch = size.height / rows;
    final r = visibleRect;

    // Banda visible acotada al tablero; sin encuadre se pinta completo.
    final left = (r?.left ?? 0.0).clamp(0.0, size.width);
    final right = (r?.right ?? size.width).clamp(0.0, size.width);
    final top = (r?.top ?? 0.0).clamp(0.0, size.height);
    final bottom = (r?.bottom ?? size.height).clamp(0.0, size.height);

    // Solo las líneas verticales cuyo índice cae dentro del encuadre.
    final firstCol = r == null ? 1 : math.max(1, (left / cw).floor());
    final lastCol =
        r == null ? cols - 1 : math.min(cols - 1, (right / cw).ceil());
    for (var i = firstCol; i <= lastCol; i++) {
      canvas.drawLine(Offset(cw * i, top), Offset(cw * i, bottom), paint);
    }

    final firstRow = r == null ? 1 : math.max(1, (top / ch).floor());
    final lastRow =
        r == null ? rows - 1 : math.min(rows - 1, (bottom / ch).ceil());
    for (var j = firstRow; j <= lastRow; j++) {
      canvas.drawLine(Offset(left, ch * j), Offset(right, ch * j), paint);
    }
  }

  /// Camino enmascarado: relleno por celda existente y rejilla SOLO entre dos
  /// celdas existentes. Cada arista interior se dibuja una vez (la derecha y
  /// la inferior de su celda dueña).
  void _paintMaskedCells(Canvas canvas, BoundingBox frame) {
    final fill = Paint()..color = surfaceColor;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Banda visible en índices de celda del marco (culling front#66); sin
    // encuadre se recorre la caja completa.
    final r = visibleRect;
    final firstCol = r == null ? 0 : math.max(0, (r.left / cell).floor());
    final lastCol = r == null
        ? frame.cols - 1
        : math.min(frame.cols - 1, (r.right / cell).ceil() - 1);
    final firstRow = r == null ? 0 : math.max(0, (r.top / cell).floor());
    final lastRow = r == null
        ? frame.rows - 1
        : math.min(frame.rows - 1, (r.bottom / cell).ceil() - 1);

    bool exists(int row, int col) => space.contains(
        Position(row: frame.minRow + row, col: frame.minCol + col));

    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (!exists(row, col)) continue;
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
        canvas.drawRect(rect, fill);
        if (exists(row, col + 1)) {
          canvas.drawLine(rect.topRight, rect.bottomRight, grid);
        }
        if (exists(row + 1, col)) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, grid);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardSurfacePainter old) =>
      old.space != space ||
      old.cell != cell ||
      old.surfaceColor != surfaceColor ||
      old.gridColor != gridColor ||
      old.visibleRect != visibleRect;
}
