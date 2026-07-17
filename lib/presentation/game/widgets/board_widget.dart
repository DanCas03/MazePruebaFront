import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/arrows/value_objects/arrow_id.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../../application/state/game_controller.dart';
import '../arrow_color_resolver.dart';
import '../painters/board_surface_painter.dart';
import '../painters/silhouette_painter.dart';
import 'arrow_widget.dart';
import 'board_viewport.dart';
import 'exiting_arrow_widget.dart';

/// Rejilla del tablero: panel dimensionado por el bounding box del ESPACIO con
/// una flecha por `Positioned` (su bounding box). El hit-testing es POR CELDA
/// mediante un único GestureDetector (a prueba de forma: recta o doblada) —
/// esto resuelve el bug de "no se sabe qué flecha se toca". Consume el estado
/// vía gameControllerProvider.
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

    // front#87: el tablero se dimensiona por la caja envolvente del ESPACIO —
    // qué celdas existen dentro de ella lo deciden el painter y el hit-testing
    // con space.contains, no una suposición rectangular.
    final frame = state.board.space.bounds;
    if (frame.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math.min(
          constraints.maxWidth / frame.cols,
          constraints.maxHeight / frame.rows,
        );
        final width = frame.cols * cell;
        final height = frame.rows * cell;

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
    final space = board.space;
    // Marco del tablero (front#87): el canvas y los Positioned trabajan con
    // origen en la esquina del bounding box (celda absoluta − frame.min…), así
    // un espacio recortado (min ≠ 0) renderiza sin reescribir las celdas de
    // sus flechas. Con los espacios actuales (origen 0) es la identidad.
    final frame = space.bounds;
    // Margen de culling: mantiene construidas las flechas que apenas rozan el
    // borde del encuadre para que no aparezcan "de golpe" al hacer pan.
    final camera = visibleRect?.inflate(cell * 2);

    bool onCamera(Arrow arrow) {
      if (camera == null) return true;
      final b = _bounds(arrow);
      final rect = Rect.fromLTWH(
        (b.minCol - frame.minCol) * cell,
        (b.minRow - frame.minRow) * cell,
        (b.maxCol - b.minCol + 1) * cell,
        (b.maxRow - b.minRow + 1) * cell,
      );
      return camera.overlaps(rect);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        // front#87: el marco solo DIMENSIONA; la existencia de cada celda la
        // decide el espacio. Un toque sobre una celda que no existe se rechaza
        // antes de resolver flecha alguna.
        final pos = Position(
          row: ((details.localPosition.dy / cell).floor() + frame.minRow)
              .clamp(frame.minRow, frame.maxRow),
          col: ((details.localPosition.dx / cell).floor() + frame.minCol)
              .clamp(frame.minCol, frame.maxCol),
        );
        if (!space.contains(pos)) return;
        final arrow = board.arrowAt(pos);
        if (arrow != null) {
          onTapArrow(arrow.id);
        }
      },
      child: Stack(
        clipBehavior: Clip.none, // la flecha saliente cruza el borde
        children: [
          // front#87: panel + rejilla se pintan A TRAVÉS del espacio (solo
          // celdas existentes); con caja llena el painter reproduce el panel
          // redondeado previo píxel a píxel.
          Positioned.fill(
            child: CustomPaint(
              painter: BoardSurfacePainter(
                space: space,
                cell: cell,
                surfaceColor: surface.withValues(alpha: 0.30),
                gridColor: gridColor,
                visibleRect: visibleRect,
              ),
            ),
          ),
          // Relleno de silueta temática (front#114): pinta cada celda de
          // región con el color tenue de su rol, DEBAJO de las flechas, para
          // que la figura no muestre huecos. Dato opaco: solo se dibuja
          // cuando el nivel trae silueta Y paleta.
          if (state.silhouette != null && state.palette != null)
            Positioned.fill(
              child: CustomPaint(
                painter: SilhouettePainter(
                  frame: frame,
                  cell: cell,
                  silhouette: state.silhouette!,
                  palette: state.palette!,
                ),
              ),
            ),
          // Culling de flechas: solo se construyen (con su AnimationController)
          // las que caen dentro de la cámara. Fuera de zoom, el encuadre cubre
          // todo el tablero, así que se construyen todas (comportamiento previo).
          for (final arrow in board.arrows)
            if (onCamera(arrow)) _positionArrow(arrow, cell, state, frame),
          // La flecha saliente es una animación transitoria que cruza el borde:
          // siempre se dibuja mientras dure, aunque su celda de origen ya no esté.
          if (state.exitingArrow != null)
            _positionExiting(state.exitingArrow!, cell, state.exitNonce, frame),
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

  Widget _positionArrow(
      Arrow arrow, double cell, GamePlaying state, BoundingBox frame) {
    final b = _bounds(arrow);
    return Positioned(
      left: (b.minCol - frame.minCol) * cell,
      top: (b.minRow - frame.minRow) * cell,
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
      Arrow arrow, double cell, int nonce, BoundingBox frame) {
    final b = _bounds(arrow);
    return Positioned(
      left: (b.minCol - frame.minCol) * cell,
      top: (b.minRow - frame.minRow) * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      // Limitación conocida (front#87): el recorrido de salida se calcula
      // contra el marco cols×rows anclado en origen (cellsToEdge); en un
      // espacio enmascarado la animación cruza las celdas ausentes hasta el
      // borde de la caja. Cosmético — se revisa con front#88 si molesta.
      child: ExitingArrowWidget(
        key: ValueKey('exiting-$nonce'),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cols: frame.cols,
        rows: frame.rows,
        cell: cell,
        color: colorResolver.colorFor(arrow, state.palette),
        nonce: nonce,
      ),
    );
  }
}
