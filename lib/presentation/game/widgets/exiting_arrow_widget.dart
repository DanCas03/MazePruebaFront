import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../painters/arrow_painter.dart';

/// Overlay cosmético de la flecha recién removida: se desliza fuera del tablero
/// en su dirección y se desvanece. Auto-desmontable: al terminar renderiza
/// vacío. Debe ir keyed por el `exitNonce` para que cada salida re-anime.
class ExitingArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;
  final double travel;
  final int nonce;

  const ExitingArrowWidget({
    super.key,
    required this.arrow,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
    required this.travel,
    required this.nonce,
  });

  @override
  State<ExitingArrowWidget> createState() => _ExitingArrowWidgetState();
}

class _ExitingArrowWidgetState extends State<ExitingArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _dirUnit() => switch (widget.arrow.direction) {
        Direction.up => const Offset(0, -1),
        Direction.down => const Offset(0, 1),
        Direction.left => const Offset(-1, 0),
        Direction.right => const Offset(1, 0),
      };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          if (_c.isCompleted) return const SizedBox.shrink();
          final t = Curves.easeIn.transform(_c.value);
          final d = _dirUnit();
          return Transform.translate(
            offset: Offset(d.dx * widget.travel * t, d.dy * widget.travel * t),
            child: Opacity(opacity: 1 - t, child: child),
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
