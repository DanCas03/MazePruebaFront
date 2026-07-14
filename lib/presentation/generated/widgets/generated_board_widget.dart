import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/game_state.dart';
import '../../../application/state/generated_game_controller.dart';
import '../../game/widgets/board_widget.dart';

/// Tablero del flujo GENERADO (front#37). Envoltorio fino que engancha el
/// [BoardView] presentacional al [generatedGameControllerProvider], reutilizando
/// exactamente el mismo render y hit-testing que la campaña sin duplicar lógica
/// de dibujo. El cortafuegos de persistencia vive en el controlador, no aquí.
class GeneratedBoardWidget extends ConsumerWidget {
  const GeneratedBoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(generatedGameControllerProvider).valueOrNull;
    if (state is! GamePlaying) return const SizedBox.shrink();
    return BoardView(
      state: state,
      onTapArrow: (id) =>
          ref.read(generatedGameControllerProvider.notifier).tapArrow(id),
    );
  }
}
