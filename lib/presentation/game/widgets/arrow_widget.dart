import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../painters/arrow_painter.dart';
import '../direction_projection.dart';

/// Pieza visual del tablero: pinta la flecha y, si está bloqueada, hace un
/// "shake" hacia su dirección de salida. NO captura toques (el hit-testing por
/// celda vive en BoardWidget); por eso va envuelta en [IgnorePointer].
class ArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;
  final bool isBlocked;
  final int blockedNonce;

  const ArrowWidget({
    super.key,
    required this.arrow,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
    required this.isBlocked,
    required this.blockedNonce,
  });

  @override
  State<ArrowWidget> createState() => _ArrowWidgetState();
}

class _ArrowWidgetState extends State<ArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(covariant ArrowWidget old) {
    super.didUpdateWidget(old);
    if (widget.isBlocked && widget.blockedNonce != old.blockedNonce) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final magnitude = math.sin(t * math.pi * 4) * (1 - t) * 7;
          final unit = directionUnit(widget.arrow.direction);
          return Transform.translate(
            offset: Offset(unit.dx * magnitude, unit.dy * magnitude),
            child: child,
          );
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: ArrowPainter(
            cells: widget.arrow.cells,
            minCol: widget.minCol,
            minRow: widget.minRow,
            cell: widget.cell,
            color: widget.color,
            headDirection: widget.arrow.headDirection,
          ),
        ),
      ),
    );
  }
}
