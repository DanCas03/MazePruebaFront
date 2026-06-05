// lib/presentation/game/painters/arrow_painter.dart

import 'package:flutter/material.dart';

import '../../../domain/game_core/value_objects/direction.dart';

/// Pinta una flecha neón (trazo redondeado + punta triangular + resplandor)
/// dentro del rectángulo del widget, orientada según [direction].
///
/// El widget contenedor ya tiene el tamaño del rectángulo que ocupa la flecha
/// (largo en el eje de la dirección, 1 celda en el otro eje), por lo que aquí
/// solo se dibuja a lo largo del eje correspondiente.
class ArrowPainter extends CustomPainter {
  final Direction direction;
  final Color color;

  const ArrowPainter({required this.direction, required this.color});

  bool get _isHorizontal =>
      direction == Direction.left || direction == Direction.right;

  @override
  void paint(Canvas canvas, Size size) {
    final shortSide = _isHorizontal ? size.height : size.width;
    final stroke = shortSide * 0.40;
    final inset = stroke * 0.65;
    final headLen = stroke * 1.25;
    final headHalf = stroke * 0.95;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Puntos del trazo (start = cola, end = base de la punta) y vértice (tip).
    late final Offset start;
    late final Offset end;
    late final Offset tip;
    switch (direction) {
      case Direction.right:
        start = Offset(inset, cy);
        end = Offset(size.width - inset - headLen, cy);
        tip = Offset(size.width - inset, cy);
      case Direction.left:
        start = Offset(size.width - inset, cy);
        end = Offset(inset + headLen, cy);
        tip = Offset(inset, cy);
      case Direction.down:
        start = Offset(cx, inset);
        end = Offset(cx, size.height - inset - headLen);
        tip = Offset(cx, size.height - inset);
      case Direction.up:
        start = Offset(cx, size.height - inset);
        end = Offset(cx, inset + headLen);
        tip = Offset(cx, inset);
    }

    // Punta triangular: base perpendicular al eje, centrada en `end`.
    final Path head = Path();
    if (_isHorizontal) {
      head
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(end.dx, end.dy - headHalf)
        ..lineTo(end.dx, end.dy + headHalf)
        ..close();
    } else {
      head
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(end.dx - headHalf, end.dy)
        ..lineTo(end.dx + headHalf, end.dy)
        ..close();
    }

    // Capa de resplandor (glow) por debajo. Suave, para un acabado maduro.
    final glow = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.45);
    canvas.drawLine(start, end, glow);
    canvas.drawPath(
      head,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.45),
    );

    // Trazo principal.
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, line);
    canvas.drawPath(head, Paint()..color = color);

    // Brillo interior sutil.
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.26
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, highlight);
  }

  @override
  bool shouldRepaint(covariant ArrowPainter oldDelegate) =>
      oldDelegate.direction != direction || oldDelegate.color != color;
}
