import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../../application/state/game_controller.dart';
import '../arrow_color.dart';
import 'arrow_widget.dart';
import 'exiting_arrow_widget.dart';

/// Rejilla del tablero: panel de `cols x rows` celdas con una flecha por
/// `Positioned` (su bounding box). El hit-testing es POR CELDA mediante un único
/// GestureDetector (a prueba de forma: recta o doblada) — esto resuelve el bug
/// de "no se sabe qué flecha se toca". Consume el estado vía gameControllerProvider.
class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).valueOrNull;
    if (state is! GamePlaying) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final gridColor = (isDark
            ? AppColors.onSurfaceMuted
            : AppColors.lightOnSurfaceMuted)
        .withValues(alpha: 0.10);

    final board = state.board;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math.min(
          constraints.maxWidth / board.cols,
          constraints.maxHeight / board.rows,
        );
        final width = board.cols * cell;
        final height = board.rows * cell;

        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final col = (details.localPosition.dx / cell)
                  .floor()
                  .clamp(0, board.cols - 1);
              final row = (details.localPosition.dy / cell)
                  .floor()
                  .clamp(0, board.rows - 1);
              final arrow = board.arrowAt(Position(row: row, col: col));
              if (arrow != null) {
                ref.read(gameControllerProvider.notifier).tapArrow(arrow.id);
              }
            },
            child: Stack(
              clipBehavior: Clip.none, // la flecha saliente cruza el borde
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surface.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(cell * 0.35),
                    ),
                    child: CustomPaint(
                      painter: _GridPainter(board.cols, board.rows, gridColor),
                    ),
                  ),
                ),
                for (final arrow in board.arrows) _positionArrow(arrow, cell, state),
                if (state.exitingArrow != null)
                  _positionExiting(state.exitingArrow!, cell, state.exitNonce, board.cols, board.rows),
              ],
            ),
          ),
        );
      },
    );
  }

  ({int minCol, int minRow, int maxCol, int maxRow}) _bounds(Arrow arrow) {
    var minCol = arrow.cells.first.col;
    var maxCol = arrow.cells.first.col;
    var minRow = arrow.cells.first.row;
    var maxRow = arrow.cells.first.row;
    for (final p in arrow.cells) {
      minCol = math.min(minCol, p.col);
      maxCol = math.max(maxCol, p.col);
      minRow = math.min(minRow, p.row);
      maxRow = math.max(maxRow, p.row);
    }
    return (minCol: minCol, minRow: minRow, maxCol: maxCol, maxRow: maxRow);
  }

  Widget _positionArrow(Arrow arrow, double cell, GamePlaying state) {
    final b = _bounds(arrow);
    return Positioned(
      left: b.minCol * cell,
      top: b.minRow * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      child: ArrowWidget(
        key: ValueKey(arrow.id.value),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cell: cell,
        color: arrowColorFor(arrow.id),
        isBlocked: state.blockedArrow == arrow.id,
        blockedNonce: state.blockedNonce,
      ),
    );
  }

  Widget _positionExiting(
      Arrow arrow, double cell, int nonce, int cols, int rows) {
    final b = _bounds(arrow);
    return Positioned(
      left: b.minCol * cell,
      top: b.minRow * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      child: ExitingArrowWidget(
        key: ValueKey('exiting-$nonce'),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cols: cols,
        rows: rows,
        cell: cell,
        color: arrowColorFor(arrow.id),
        nonce: nonce,
      ),
    );
  }
}

/// Rejilla de fondo muy sutil.
class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final Color color;
  const _GridPainter(this.cols, this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cw = size.width / cols;
    final ch = size.height / rows;
    for (var i = 1; i < cols; i++) {
      canvas.drawLine(Offset(cw * i, 0), Offset(cw * i, size.height), paint);
    }
    for (var j = 1; j < rows; j++) {
      canvas.drawLine(Offset(0, ch * j), Offset(size.width, ch * j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols || old.rows != rows || old.color != color;
}
