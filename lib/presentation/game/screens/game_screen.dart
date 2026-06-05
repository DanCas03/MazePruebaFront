import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/game_controller_provider.dart';
import '../../../application/providers/level_progress_providers.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/game_core/value_objects/arrow_id.dart';
import '../../../domain/game_core/value_objects/level_id.dart';
import '../widgets/board_widget.dart';

/// Pantalla de juego. Genera el tablero del nivel, lo `watch`ea y decide el
/// render con un `switch` exhaustivo sobre la `sealed class` [GameState].
class GameScreen extends ConsumerStatefulWidget {
  final LevelId levelId;

  const GameScreen({super.key, required this.levelId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final notifier = ref.read(gameControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [AppColors.background, AppColors.backgroundDeep],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: switch (state) {
              GameLoading() => const Center(
                  key: ValueKey('loading'),
                  child: CircularProgressIndicator(),
                ),
              final GamePlaying playing => _PlayingView(
                  key: const ValueKey('playing'),
                  state: playing,
                  levelId: widget.levelId,
                  onArrowTap: notifier.onArrowTapped,
                  onUndo: notifier.onUndo,
                  onRestart: notifier.onRestart,
                ),
              final GameWon won => _WonView(
                  key: const ValueKey('won'),
                  moves: won.moves.value,
                  levelId: widget.levelId,
                  onRetry: notifier.onRestart,
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _PlayingView extends StatelessWidget {
  final GamePlaying state;
  final LevelId levelId;
  final void Function(ArrowId id) onArrowTap;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  const _PlayingView({
    super.key,
    required this.state,
    required this.levelId,
    required this.onArrowTap,
    required this.onUndo,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(
          levelId: levelId,
          remaining: state.board.remaining,
          canUndo: state.canUndo,
          onUndo: onUndo,
          onRestart: onRestart,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: BoardWidget(
                board: state.board,
                blockedArrow: state.blockedArrow,
                blockedNonce: state.blockedNonce,
                exitingArrow: state.exitingArrow,
                exitNonce: state.exitNonce,
                onArrowTap: onArrowTap,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final LevelId levelId;
  final int remaining;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  const _TopBar({
    required this.levelId,
    required this.remaining,
    required this.canUndo,
    required this.onUndo,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '${levelId.value}',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          _CircleButton(
            icon: Icons.undo,
            enabled: canUndo,
            onTap: onUndo,
          ),
          const SizedBox(width: 10),
          _CircleButton(icon: Icons.refresh, onTap: onRestart),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: AppColors.onSurface, size: 20),
          ),
        ),
      ),
    );
  }
}

class _WonView extends ConsumerWidget {
  final int moves;
  final LevelId levelId;
  final VoidCallback onRetry;

  const _WonView({
    super.key,
    required this.moves,
    required this.levelId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, t, child) =>
                  Transform.scale(scale: t, child: child),
              child: const Icon(
                Icons.emoji_events,
                size: 96,
                color: AppColors.victory,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Tablero limpio!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nivel ${levelId.value} · $moves movimientos',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Siguiente nivel'),
              onPressed: () {
                ref.invalidate(levelProgressListProvider);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) =>
                        GameScreen(levelId: LevelId(levelId.value + 1)),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.replay),
              label: const Text('Reintentar'),
              onPressed: onRetry,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.invalidate(levelProgressListProvider);
                Navigator.of(context).pop();
              },
              child: const Text('Volver a niveles'),
            ),
          ],
        ),
      ),
    );
  }
}
