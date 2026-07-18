import 'package:flutter/material.dart';

import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../geometry/hex_geometry.dart';

/// Superficie del tablero hexagonal flat-top (front#126): rellena cada celda
/// existente como hexágono y traza cada arista interior UNA vez (frontera con
/// celda ausente = borde del relleno, como el masked rect). Painter separado del
/// rectangular para no tocar su lock byte a byte (canvas-call level).
class HexBoardSurfacePainter extends CustomPainter {
  final HexSpace space;
  final HexGeometry geometry;
  final Color surfaceColor;
  final Color gridColor;

  const HexBoardSurfacePainter({
    required this.space,
    required this.geometry,
    required this.surfaceColor,
    required this.gridColor,
  });

  // Una dirección por par opuesto (up/down, upLeft/downRight, upRight/downLeft)
  // => cada arista compartida se dibuja una vez. Mapeo a los índices de
  // vértice de HexGeometry.cellVertices.
  static const _canonical = <Direction, (int, int)>{
    Direction.down: (1, 2),
    Direction.downRight: (0, 1),
    Direction.downLeft: (2, 3),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = surfaceColor;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final cell in space.allCells) {
      final v = geometry.cellVertices(cell);
      final path = Path()..moveTo(v.first.dx, v.first.dy);
      for (final p in v.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, fill);

      _canonical.forEach((dir, idx) {
        if (space.step(cell, dir) != null) {
          canvas.drawLine(v[idx.$1], v[idx.$2], grid);
        }
      });
    }
  }

  @override
  bool shouldRepaint(covariant HexBoardSurfacePainter old) =>
      old.space != space ||
      old.geometry.size != geometry.size ||
      old.surfaceColor != surfaceColor ||
      old.gridColor != gridColor;
}
