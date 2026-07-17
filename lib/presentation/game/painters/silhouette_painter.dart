import 'package:flutter/material.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../arrow_color_resolver.dart';

/// Relleno de silueta temática (front#114): pinta cada celda de región con el
/// color de su rol (tenue), DEBAJO de las flechas, para que la figura no tenga
/// huecos visibles. Dato opaco: no afecta solubilidad ni hit-testing. Se salta
/// roles ausentes en la paleta o con hex inválido (misma tolerancia que el seam
/// de color de flechas).
class SilhouettePainter extends CustomPainter {
  final BoundingBox frame;
  final double cell;
  final Map<String, List<Position>> silhouette;
  final Map<String, String> palette;
  final double alpha;

  const SilhouettePainter({
    required this.frame,
    required this.cell,
    required this.silhouette,
    required this.palette,
    this.alpha = 0.30,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in silhouette.entries) {
      final hex = palette[entry.key];
      if (hex == null) continue;
      final base = ThemedArrowColorResolver.parseHexColor(hex);
      if (base == null) continue;
      final paint = Paint()..color = base.withValues(alpha: alpha);
      for (final p in entry.value) {
        final rect = Rect.fromLTWH(
          (p.col - frame.minCol) * cell,
          (p.row - frame.minRow) * cell,
          cell, cell,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SilhouettePainter old) =>
      old.frame != frame ||
      old.cell != cell ||
      old.silhouette != silhouette ||
      old.palette != palette ||
      old.alpha != alpha;
}
