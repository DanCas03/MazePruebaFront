// lib/presentation/game/widgets/exiting_arrow_widget.dart

import 'package:flutter/material.dart';

import '../../../core/constants/durations.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../painters/arrow_painter.dart';

/// Overlay puramente visual: cuando una flecha sale con éxito, se renderiza
/// aquí deslizándose en su dirección hasta abandonar la pantalla y desvanecerse.
///
/// La lógica de dominio ya retiró la flecha del tablero (la celda quedó libre);
/// esta animación es cosmética y no captura toques ([IgnorePointer]).
class ExitingArrowWidget extends StatefulWidget {
  final Direction direction;
  final Color color;

  /// Distancia (px) que recorre para salir del área visible.
  final double travel;

  /// Cambia en cada salida para re-disparar la animación.
  final int nonce;

  const ExitingArrowWidget({
    super.key,
    required this.direction,
    required this.color,
    required this.travel,
    required this.nonce,
  });

  @override
  State<ExitingArrowWidget> createState() => _ExitingArrowWidgetState();
}

class _ExitingArrowWidgetState extends State<ExitingArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kArrowExitDuration,
  )..forward();

  @override
  void didUpdateWidget(covariant ExitingArrowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nonce != oldWidget.nonce) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Aceleración: la flecha "sale disparada".
          final t = Curves.easeIn.transform(_controller.value);
          final opacity = (1 - (t - 0.55) / 0.45).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(
              widget.direction.dx * widget.travel * t,
              widget.direction.dy * widget.travel * t,
            ),
            child: Opacity(opacity: opacity, child: child),
          );
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: ArrowPainter(direction: widget.direction, color: widget.color),
        ),
      ),
    );
  }
}
