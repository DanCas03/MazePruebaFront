import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../painters/arrow_painter.dart';

// Animates an arrow sliding off the board in its direction, then fading out.
// Encapsula la animacion de salida (SRP) para que el tablero solo decida
// cuando montarla; al terminar notifica con [onComplete] para que el estado
// reactivo retire la pieza.
class ExitingArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final double cellSize;
  final VoidCallback onComplete;

  const ExitingArrowWidget({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.onComplete,
  });

  @override
  State<ExitingArrowWidget> createState() => _ExitingArrowWidgetState();
}

class _ExitingArrowWidgetState extends State<ExitingArrowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    final slideEnd = switch (widget.arrow.direction) {
      Direction.right => const Offset(1.5, 0),
      Direction.left => const Offset(-1.5, 0),
      Direction.down => const Offset(0, 1.5),
      Direction.up => const Offset(0, -1.5),
    };
    _slideAnim = Tween<Offset>(begin: Offset.zero, end: slideEnd)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _fadeAnim = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: CustomPaint(
          painter: ArrowPainter(
            arrow: widget.arrow,
            cellSize: widget.cellSize,
            isHighlighted: true,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
