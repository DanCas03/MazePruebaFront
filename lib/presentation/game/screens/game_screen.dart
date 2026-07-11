import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/providers/leaderboard_providers.dart';
import '../../../application/state/game_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/board/value_objects/level_id.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/game_provider.dart';
import '../widgets/board_widget.dart';

// Re-exporta el provider para que el router (core) referencie GameScreen sin
// alcanzar application/state directamente; presentation es el unico punto de
// entrada al estado de juego.
export '../../providers/game_provider.dart' show gameControllerProvider;

/// Pantalla principal de partida. Recibe el [levelId] del router y dispara
/// [loadLevel] en el primer frame via addPostFrameCallback para garantizar que
/// el ProviderScope este montado antes de leer el notifier.
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
    // Post-frame: garantiza que build() haya corrido al menos una vez y el
    // ProviderScope este activo antes de mutar el estado del notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(gameControllerProvider);

    // Activa el Observer que envía el score al ganar (front#16). Mantiene vivo
    // el listener mientras esta pantalla esté montada.
    ref.watch(scoreSubmissionObserverProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final onSurface =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final accent = isDark ? AppColors.secondary : AppColors.lightSecondary;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    ref.listen(gameControllerProvider, (_, next) {
      final state = next.valueOrNull;
      if (state is GameWon) {
        Navigator.pushReplacementNamed(context, AppRouter.victory,
            arguments: state.moves.value);
      } else if (state is GameLost) {
        // La derrota lleva el LevelId para que el CTA "Retry" recargue el nivel.
        Navigator.pushReplacementNamed(
          context,
          AppRouter.defeat,
          arguments: (
            levelId: widget.levelId,
            moves: state.moves.value,
            strikes: state.strikes.value,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: surface,
        title: asyncState.when(
          data: (s) => s is GamePlaying
              ? Text(l10n.gameMoves(s.moves.value),
                  style: TextStyle(color: onSurface))
              : Text(l10n.appTitle),
          loading: () => Text(l10n.loading),
          error: (e, _) => Text(l10n.error),
        ),
        actions: [
          // Cuenta atrás de los niveles con límite (front#11); ausente si el
          // nivel no está cronometrado.
          ...asyncState.maybeWhen(
            data: (s) => s is GamePlaying && s.remainingSeconds != null
                ? [_CountdownChip(seconds: s.remainingSeconds!, color: onSurface)]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
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

/// Reloj de la partida en la AppBar: muestra los segundos restantes como `m:ss`.
class _CountdownChip extends StatelessWidget {
  final int seconds;
  final Color color;
  const _CountdownChip({required this.seconds, required this.color});

  String get _label {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final rest = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: color, size: 18),
          const SizedBox(width: 4),
          Text(_label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
