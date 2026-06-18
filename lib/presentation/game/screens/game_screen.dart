import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/game_provider.dart';
import '../widgets/board_widget.dart';

// Re-exporta el provider para que el router (core) referencie GameScreen sin
// alcanzar application/state directamente; presentation es el unico punto de
// entrada al estado de juego.
export '../../providers/game_provider.dart' show gameControllerProvider;

/// Pantalla principal de partida: scaffold con el tablero, el contador de
/// movimientos en el AppBar y la accion de deshacer. Observa el estado reactivo
/// y, al ganar, navega a la pantalla de victoria pasando los movimientos.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(gameControllerProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final onSurface =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final accent = isDark ? AppColors.secondary : AppColors.lightSecondary;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    ref.listen(gameControllerProvider, (_, next) {
      if (next.valueOrNull is GameWon) {
        final moves = (next.valueOrNull as GameWon).moves.value;
        Navigator.pushReplacementNamed(context, AppRouter.victory,
            arguments: moves);
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: surface,
        title: asyncState.when(
          data: (s) => s is GamePlaying
              ? Text('Moves: ${s.moves.value}',
                  style: TextStyle(color: onSurface))
              : const Text('Arrow Maze'),
          loading: () => const Text('Loading...'),
          error: (e, _) => const Text('Error'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.undo, color: accent),
            onPressed: () =>
                ref.read(gameControllerProvider.notifier).undoMove(),
          ),
        ],
      ),
      body: Center(
        child: asyncState.when(
          data: (_) => const BoardWidget(),
          loading: () => CircularProgressIndicator(color: primary),
          error: (e, _) => Text('$e'),
        ),
      ),
    );
  }
}
