import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../painters/snake_exit_painter.dart';

/// Overlay cosmético de la flecha removida: retracción "serpiente" cabeza
/// primero (la cabeza sale y la cola la sigue por su propio camino). Auto-
/// desmontable: al terminar renderiza vacío. Keyed por `exitNonce` para que
/// cada salida re-anime.
class ExitingArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final int minCol;
  final int minRow;
  final int cols;
  final int rows;
  final double cell;
  final Color color;
  final int nonce;

  // Duración del slide de salida. Fija en 360 ms para el gameplay normal; el
  // auto-solver (#102) la comprime en tableros grandes para poder acelerar su
  // ritmo sin cortar la animación a mitad de camino (ver AutoSolvePacing).
  final Duration duration;

  const ExitingArrowWidget({
    super.key,
    required this.arrow,
    required this.minCol,
    required this.minRow,
    required this.cols,
    required this.rows,
    required this.cell,
    required this.color,
    required this.nonce,
    this.duration = const Duration(milliseconds: 360),
  });

  @override
  State<ExitingArrowWidget> createState() => _ExitingArrowWidgetState();
}

class _ExitingArrowWidgetState extends State<ExitingArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isCompleted) return const SizedBox.shrink();
          final t = Curves.easeIn.transform(_c.value);
          return CustomPaint(
            size: Size.infinite,
            painter: SnakeExitPainter(
              cells: widget.arrow.cells,
              headDirection: widget.arrow.headDirection,
              minCol: widget.minCol,
              minRow: widget.minRow,
              cols: widget.cols,
              rows: widget.rows,
              cell: widget.cell,
              color: widget.color,
              progress: t,
            ),
          );
        },
      ),
    );
  }
}
