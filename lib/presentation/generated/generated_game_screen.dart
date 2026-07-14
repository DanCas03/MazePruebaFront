import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/audio/i_audio_service.dart';
import '../../application/state/game_state.dart';
import '../../application/state/generated_game_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../core/di/dependency_providers.dart';
import 'widgets/generated_board_widget.dart';
import 'widgets/seed_chip.dart';

/// Pantalla de partida del flujo GENERADO (front#37). Reutiliza las mecánicas
/// (BoardView + strikes + contrarreloj) vía [generatedGameControllerProvider],
/// pero su HUD es deliberadamente MÍNIMO respecto a la campaña:
///   - muestra la semilla de forma sutil, con botón de copiado;
///   - conserva movimientos, reloj (solo si se activó) y deshacer;
///   - OCULTA por completo pistas, puntajes y estrellas (no existen aquí).
///
/// Cortafuegos: NO observa `scoreSubmissionObserverProvider`, así que ganar
/// jamás dispara un envío al leaderboard. El tablero ya lo montó el configurador
/// (o una acción post-partida) antes de navegar aquí; esta pantalla solo observa.
class GeneratedGameScreen extends ConsumerStatefulWidget {
  const GeneratedGameScreen({super.key});

  @override
  ConsumerState<GeneratedGameScreen> createState() =>
      _GeneratedGameScreenState();
}

class _GeneratedGameScreenState extends ConsumerState<GeneratedGameScreen> {
  // Capturado en initState: el audio se detiene en dispose(), donde `ref` ya no
  // es accesible. El provider no es autoDispose, así que la referencia es estable.
  late final IAudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _audio.startMusic());
  }

  @override
  void dispose() {
    _audio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(generatedGameControllerProvider);
    final seed = ref.read(generatedGameControllerProvider.notifier).currentSeed;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final onSurface =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final accent = isDark ? AppColors.secondary : AppColors.lightSecondary;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    ref.listen(generatedGameControllerProvider, (prev, next) {
      final audio = _audio;
      final prevState = prev?.valueOrNull;
      final state = next.valueOrNull;

      // SFX por transición de nonce (señales transitorias de GamePlaying):
      // exitNonce++ = flecha que sale; blockedNonce++ = choque.
      if (prevState is GamePlaying && state is GamePlaying) {
        if (state.exitNonce > prevState.exitNonce) {
          audio.play(GameSound.exit);
        }
        if (state.blockedNonce > prevState.blockedNonce) {
          audio.play(GameSound.collision);
        }
      }

      if (state is GeneratedCleared) {
        audio.play(GameSound.victory);
        audio.stopMusic();
        Navigator.pushReplacementNamed(
          context,
          AppRouter.generatedResult,
          arguments: (won: true, moves: state.moves.value),
        );
      } else if (state is GameLost) {
        audio.play(GameSound.defeat);
        audio.stopMusic();
        Navigator.pushReplacementNamed(
          context,
          AppRouter.generatedResult,
          arguments: (won: false, moves: state.moves.value),
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
          // Cuenta atrás solo si el jugador activó el modo contrarreloj.
          ...asyncState.maybeWhen(
            data: (s) => s is GamePlaying && s.remainingSeconds != null
                ? [_CountdownChip(seconds: s.remainingSeconds!, color: onSurface)]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
          IconButton(
            icon: Icon(Icons.undo, color: accent),
            onPressed: () =>
                ref.read(generatedGameControllerProvider.notifier).undoMove(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: asyncState.when(
                data: (_) => const GeneratedBoardWidget(),
                loading: () => CircularProgressIndicator(color: primary),
                error: (e, _) => Text(l10n.error),
              ),
            ),
          ),
          // Semilla sutil al pie: siempre visible durante la partida para que el
          // jugador pueda copiarla y reproducir el tablero.
          if (seed != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: SeedChip(seed: seed, compact: true),
            ),
        ],
      ),
    );
  }
}

/// Reloj de la partida en la AppBar: segundos restantes como `m:ss`. Copia del
/// chip de la campaña (front#11); se mantiene local para no acoplar este flujo
/// a los internals de la pantalla de campaña.
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
