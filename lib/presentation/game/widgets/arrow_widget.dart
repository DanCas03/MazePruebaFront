// lib/presentation/game/widgets/arrow_widget.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/game_core/value_objects/direction.dart';
import '../painters/arrow_painter.dart';

/// Flecha interactiva. Dibuja el trazo neón ([ArrowPainter]) y reacciona al
/// toque. Si está bloqueada, ejecuta una animación de "shake" (sacudida hacia
/// su dirección de salida) para comunicar que no puede salir.
class ArrowWidget extends StatefulWidget {
  final Direction direction;
  final Color color;
  final bool isBlocked;
  final int blockedNonce;
  final VoidCallback onTap;

  const ArrowWidget({
    super.key,
    required this.direction,
    required this.color,
    required this.isBlocked,
    required this.blockedNonce,
    required this.onTap,
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
  void didUpdateWidget(covariant ArrowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBlocked && widget.blockedNonce != oldWidget.blockedNonce) {
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final magnitude = math.sin(t * math.pi * 4) * (1 - t) * 7;
          return Transform.translate(
            offset: Offset(
              widget.direction.dx * magnitude,
              widget.direction.dy * magnitude,
            ),
            child: child,
          );
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: ArrowPainter(
            direction: widget.direction,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
