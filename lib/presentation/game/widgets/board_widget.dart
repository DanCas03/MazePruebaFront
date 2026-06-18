import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import 'arrow_widget.dart';

/// Rejilla del tablero: dibuja un panel de `cols x rows` celdas y superpone una
/// [ArrowWidget] por cada flecha. Consume el estado reactivo via
/// `gameControllerProvider` (presentation -> application; nunca infrastructure)
/// y delega el toque al controller para mantener la UI sin logica de juego.
class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  static const double _cellSize = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).valueOrNull;
    if (state is! GamePlaying) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final border = isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;

    final board = state.board;
    final width = board.cols * _cellSize;
    final height = board.rows * _cellSize;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
      ),
      child: Stack(
        children: board.arrows.map((arrow) {
          // La key estable por id permite a Flutter reutilizar el elemento de
          // cada pieza entre rebuilds (evita reanimar piezas que no cambiaron).
          return ArrowWidget(
            key: ValueKey(arrow.id.value),
            arrow: arrow,
            cellSize: _cellSize,
            onTap: () => ref
                .read(gameControllerProvider.notifier)
                .tapArrow(arrow.id),
          );
        }).toList(),
      ),
    );
  }
}
