import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/arrows/value_objects/arrow_id.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../../application/state/game_controller.dart';
import '../arrow_color_resolver.dart';
import 'arrow_widget.dart';
import 'board_viewport.dart';
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
    return BoardView(
      state: state,
      colorResolver: ref.watch(arrowColorResolverProvider),
      onTapArrow: (id) =>
          ref.read(gameControllerProvider.notifier).tapArrow(id),
    );
  }
}

/// Vista presentacional PURA del tablero: recibe el [GamePlaying] y el callback
/// de toque, sin conocer QUÉ controlador lo alimenta. La extrae de [BoardWidget]
/// para que el flujo de tableros generados (front#37) reutilice exactamente el
/// mismo render y hit-testing enganchando su propio controlador, manteniendo
/// una única fuente de la lógica de dibujo (DRY).
class BoardView extends StatelessWidget {
  final GamePlaying state;
  final void Function(ArrowId arrowId) onTapArrow;

  /// Seam de color (front#67): decide el Color de cada flecha. Default temático
  /// que cae a identidad sin Instrucciones de pintado, así los call sites que no
  /// lo inyectan (flujo generado, tests) pintan igual que antes. [BoardWidget] lo
  /// inyecta desde `arrowColorResolverProvider`.
  final ArrowColorResolver colorResolver;

  const BoardView({
    super.key,
    required this.state,
    required this.onTapArrow,
    this.colorResolver = const ThemedArrowColorResolver(),
  });

  @override
  Widget build(BuildContext context) {
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

        // front#66: la cámara (zoom/pan + doble-tap) envuelve el tablero ya
        // ajustado a "fit" y alimenta el rectángulo visible para el culling.
        return BoardViewport(
          viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
          boardSize: Size(width, height),
          builder: (visibleRect) => _boardContent(
            context: context,
            cell: cell,
            surface: surface,
            gridColor: gridColor,
            visibleRect: visibleRect,
          ),
        );
      },
    );
  }

  Widget _boardContent({
    required BuildContext context,
    required double cell,
    required Color surface,
    required Color gridColor,
    required Rect? visibleRect,
  }) {
    final board = state.board;
    // Margen de culling: mantiene construidas las flechas que apenas rozan el
    // borde del encuadre para que no aparezcan "de golpe" al hacer pan.
    final camera = visibleRect?.inflate(cell * 2);

    bool onCamera(Arrow arrow) {
      if (camera == null) return true;
      final b = _bounds(arrow);
      final rect = Rect.fromLTWH(
        b.minCol * cell,
        b.minRow * cell,
        (b.maxCol - b.minCol + 1) * cell,
        (b.maxRow - b.minRow + 1) * cell,
      );
      return camera.overlaps(rect);
    }

    return GestureDetector(
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
          onTapArrow(arrow.id);
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
                painter:
                    _GridPainter(board.cols, board.rows, gridColor, visibleRect),
              ),
            ),
          ),
          // Culling de flechas: solo se construyen (con su AnimationController)
          // las que caen dentro de la cámara. Fuera de zoom, el encuadre cubre
          // todo el tablero, así que se construyen todas (comportamiento previo).
          for (final arrow in board.arrows)
            if (onCamera(arrow)) _positionArrow(arrow, cell, state),
          // La flecha saliente es una animación transitoria que cruza el borde:
          // siempre se dibuja mientras dure, aunque su celda de origen ya no esté.
          if (state.exitingArrow != null)
            _positionExiting(state.exitingArrow!, cell, state.exitNonce,
                board.cols, board.rows),
        ],
      ),
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
        color: colorResolver.colorFor(arrow, state.palette),
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
        color: colorResolver.colorFor(arrow, state.palette),
        nonce: nonce,
      ),
    );
  }
}

/// Rejilla de fondo muy sutil con culling por viewport (front#66): en un XL de
/// 50×50 dibujar las 98 líneas completas en cada frame de pan es desperdicio;
/// [visibleRect] (coords locales del tablero) acota QUÉ líneas se dibujan y las
/// recorta al alto/ancho del encuadre. `null` ⇒ se dibuja el tablero entero.
class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final Color color;
  final Rect? visibleRect;
  const _GridPainter(this.cols, this.rows, this.color, [this.visibleRect]);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cw = size.width / cols;
    final ch = size.height / rows;
    final r = visibleRect;

    // Banda visible acotada al tablero; sin encuadre se pinta completo.
    final left = (r?.left ?? 0.0).clamp(0.0, size.width);
    final right = (r?.right ?? size.width).clamp(0.0, size.width);
    final top = (r?.top ?? 0.0).clamp(0.0, size.height);
    final bottom = (r?.bottom ?? size.height).clamp(0.0, size.height);

    // Solo las líneas verticales cuyo índice cae dentro del encuadre.
    final firstCol = r == null ? 1 : math.max(1, (left / cw).floor());
    final lastCol = r == null ? cols - 1 : math.min(cols - 1, (right / cw).ceil());
    for (var i = firstCol; i <= lastCol; i++) {
      canvas.drawLine(Offset(cw * i, top), Offset(cw * i, bottom), paint);
    }

    final firstRow = r == null ? 1 : math.max(1, (top / ch).floor());
    final lastRow = r == null ? rows - 1 : math.min(rows - 1, (bottom / ch).ceil());
    for (var j = firstRow; j <= lastRow; j++) {
      canvas.drawLine(Offset(left, ch * j), Offset(right, ch * j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.color != color ||
      old.visibleRect != visibleRect;
}
