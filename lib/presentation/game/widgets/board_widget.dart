// lib/presentation/game/widgets/board_widget.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/arrows/entities/arrow_board.dart';
import '../../../domain/game_core/value_objects/arrow_id.dart';
import 'arrow_widget.dart';
import 'exiting_arrow_widget.dart';

/// Dibuja el tablero cuadrado: una rejilla sutil de fondo y, sobre ella, cada
/// flecha posicionada en el rectángulo de celdas que ocupa. Sobre todo eso,
/// un overlay opcional con la flecha que está saliendo (animación de acierto).
///
/// Widget de presentación puro: recibe el [ArrowBoard] y callbacks; no conoce
/// Riverpod ni el controlador.
class BoardWidget extends StatelessWidget {
  final ArrowBoard board;
  final ArrowId? blockedArrow;
  final int blockedNonce;
  final Arrow? exitingArrow;
  final int exitNonce;
  final void Function(ArrowId id) onArrowTap;

  const BoardWidget({
    super.key,
    required this.board,
    required this.blockedArrow,
    required this.blockedNonce,
    required this.exitingArrow,
    required this.exitNonce,
    required this.onArrowTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final cell = side / board.width;

        return SizedBox(
          width: side,
          height: side,
          child: Stack(
            clipBehavior: Clip.none, // deja que la flecha saliente cruce el borde
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(cell * 0.4),
                  ),
                  child: CustomPaint(painter: _GridPainter(board.width)),
                ),
              ),
              for (final arrow in board.arrows) _positionArrow(arrow, cell),
              if (exitingArrow != null) _positionExiting(exitingArrow!, cell, side),
            ],
          ),
        );
      },
    );
  }

  ({double left, double top, double width, double height}) _rectFor(
    Arrow arrow,
    double cell,
  ) {
    final cells = arrow.cells;
    var minX = cells.first.x;
    var maxX = cells.first.x;
    var minY = cells.first.y;
    var maxY = cells.first.y;
    for (final p in cells) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return (
      left: minX * cell,
      top: minY * cell,
      width: (maxX - minX + 1) * cell,
      height: (maxY - minY + 1) * cell,
    );
  }

  Widget _positionArrow(Arrow arrow, double cell) {
    final r = _rectFor(arrow, cell);
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: ArrowWidget(
        key: ValueKey(arrow.id.value),
        direction: arrow.direction,
        color: AppColors.arrowColor(arrow.colorIndex),
        isBlocked: blockedArrow == arrow.id,
        blockedNonce: blockedNonce,
        onTap: () => onArrowTap(arrow.id),
      ),
    );
  }

  Widget _positionExiting(Arrow arrow, double cell, double side) {
    final r = _rectFor(arrow, cell);
    return Positioned(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
      child: ExitingArrowWidget(
        direction: arrow.direction,
        color: AppColors.arrowColor(arrow.colorIndex),
        travel: side * 1.15,
        nonce: exitNonce,
      ),
    );
  }
}

/// Rejilla de fondo muy sutil para dar sensación de cuadrícula.
class _GridPainter extends CustomPainter {
  final int divisions;

  const _GridPainter(this.divisions);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final cell = size.width / divisions;
    for (var i = 1; i < divisions; i++) {
      canvas.drawLine(Offset(cell * i, 0), Offset(cell * i, size.height), paint);
      canvas.drawLine(Offset(0, cell * i), Offset(size.width, cell * i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.divisions != divisions;
}
