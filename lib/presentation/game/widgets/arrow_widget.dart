import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../painters/arrow_painter.dart';

/// Pieza tappable del tablero: un [GestureDetector] sobre un [CustomPaint] que
/// delega el dibujo 3D al [ArrowPainter]. El widget no contiene logica de
/// juego (SRP); solo enlaza el toque con el callback que provee el tablero.
class ArrowWidget extends StatelessWidget {
  final Arrow arrow;
  final double cellSize;
  final bool isHighlighted;
  final VoidCallback onTap;

  const ArrowWidget({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: ArrowPainter(
          arrow: arrow,
          cellSize: cellSize,
          isHighlighted: isHighlighted,
        ),
        size: Size.infinite,
      ),
    );
  }
}
