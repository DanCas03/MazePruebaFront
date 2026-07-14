import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/audio/i_audio_service.dart';
import '../../../application/providers/leaderboard_providers.dart';
import '../../../application/providers/progress_providers.dart';
import '../../../application/state/game_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/board/failures/level_failure.dart';
import '../../../domain/board/services/hint_policy.dart';
import '../../../domain/board/value_objects/level_id.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/di/dependency_providers.dart';
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
  // Referencia capturada en initState: el audio se usa en dispose(), donde `ref`
  // ya no es accesible. El provider no es autoDispose, asi que es estable.
  late final IAudioService _audio;

  // #32: umbral de elegibilidad de la pista, fuente única compartida con el
  // controlador. Decide si se pinta el botón de la bombilla en este nivel.
  static const _hintPolicy = HintPolicy();

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    // Post-frame: garantiza que build() haya corrido al menos una vez y el
    // ProviderScope este activo antes de mutar el estado del notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId);
      // front#5: arranca la musica de fondo al entrar en la partida.
      _audio.startMusic();
    });
  }

  @override
  void dispose() {
    // front#5: detiene la musica de fondo al salir de la partida.
    _audio.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(gameControllerProvider);

    // Activa el Observer que envía el score al ganar (front#16). Mantiene vivo
    // el listener mientras esta pantalla esté montada.
    ref.watch(scoreSubmissionObserverProvider);

    // front#58: Observer que persiste el progreso LOCAL al ganar (completado +
    // best score/estrellas). Es el productor que alimenta las estrellas del
    // selector de nivel y el gating de tiers (front#20).
    ref.watch(levelCompletionObserverProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final onSurface =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final accent = isDark ? AppColors.secondary : AppColors.lightSecondary;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;

    ref.listen(gameControllerProvider, (prev, next) {
      // front#5: observador de audio. El dominio/aplicacion no conocen el
      // sonido; aqui se traducen las senales de estado a eventos sonoros.
      final audio = _audio;
      final prevState = prev?.valueOrNull;
      final state = next.valueOrNull;

      // SFX por transicion de nonce (senales transitorias de GamePlaying):
      // exitNonce++ = flecha que sale; blockedNonce++ = choque.
      if (prevState is GamePlaying && state is GamePlaying) {
        if (state.exitNonce > prevState.exitNonce) {
          audio.play(GameSound.exit);
        }
        if (state.blockedNonce > prevState.blockedNonce) {
          audio.play(GameSound.collision);
        }
        // #32: la pista falló o expiró (el back no respondió a tiempo). La
        // partida queda intacta; solo avisamos con un snackbar no intrusivo.
        if (state.hintErrorNonce > prevState.hintErrorNonce) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.hintError)));
        }
      }

      if (state is GameWon) {
        audio.play(GameSound.victory);
        audio.stopMusic();
        // La victoria viaja con el nivel (para "Next Level") y las métricas ya
        // evaluadas por el controller (front#16). La pantalla es una vista
        // pasiva que solo las pinta.
        Navigator.pushReplacementNamed(
          context,
          AppRouter.victory,
          arguments: (
            levelId: state.levelId,
            moves: state.moves.value,
            score: state.score.value,
            stars: state.stars.value,
          ),
        );
      } else if (state is GameLost) {
        audio.play(GameSound.defeat);
        audio.stopMusic();
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
          // #32: botón de pista, solo en niveles elegibles y durante el juego.
          // La bombilla se transforma en un spinner mientras la solución viaja
          // (mitiga dobles clics) y queda inerte durante la reproducción.
          ...asyncState.maybeWhen(
            data: (s) => s is GamePlaying && _hintPolicy.isEligible(widget.levelId)
                ? [
                    _HintButton(
                      loading: s.hintLoading,
                      playing: s.hintPlaying,
                      color: accent,
                      tooltip: l10n.hintTooltip,
                      onPressed: () =>
                          ref.read(gameControllerProvider.notifier).playHint(),
                    )
                  ]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
          IconButton(
            icon: Icon(Icons.undo, color: accent),
            // Undo deshabilitado mientras la pista está activa (#32).
            onPressed: asyncState.maybeWhen(
              data: (s) =>
                  s is GamePlaying && (s.hintLoading || s.hintPlaying)
                      ? null
                      : () =>
                          ref.read(gameControllerProvider.notifier).undoMove(),
              orElse: () =>
                  () => ref.read(gameControllerProvider.notifier).undoMove(),
            ),
          ),
        ],
      ),
      body: Center(
        child: asyncState.when(
          data: (_) => const BoardWidget(),
          loading: () => CircularProgressIndicator(color: primary),
          error: (e, _) => _GameError(
            failure: e,
            onRetry: () =>
                ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId),
          ),
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

/// Botón de la pista auto-resolutora (#32). Tres aspectos según el sub-estado:
/// - inactivo: bombilla de contorno, pulsable (dispara [onPressed]).
/// - cargando: un spinner sustituye a la bombilla y el botón queda inerte, para
///   mitigar dobles clics mientras la solución viaja por HTTP.
/// - reproduciendo: bombilla rellena y atenuada, inerte (la demo está en curso).
class _HintButton extends StatelessWidget {
  final bool loading;
  final bool playing;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _HintButton({
    required this.loading,
    required this.playing,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      // Mismo footprint que un IconButton para no saltar el layout del AppBar.
      return Semantics(
        label: tooltip,
        child: SizedBox(
          width: kMinInteractiveDimension,
          height: kMinInteractiveDimension,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ),
        ),
      );
    }
    if (playing) {
      return IconButton(
        icon: Icon(Icons.lightbulb, color: color.withValues(alpha: 0.38)),
        tooltip: tooltip,
        onPressed: null, // inerte durante la reproducción de la solución
      );
    }
    return IconButton(
      icon: Icon(Icons.lightbulb_outline, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// Rama de error de la carga remota del nivel. Discrimina el LevelFailure:
/// LevelUnavailable (sin conexión) ofrece reintentar; el resto (no encontrado /
/// corrupto) es terminal y vuelve al selector. Recibe el fallo como `Object`
/// (lo que entrega `AsyncError`) y hace el type-check aquí.
class _GameError extends StatelessWidget {
  final Object failure;
  final VoidCallback onRetry;
  const _GameError({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (failure is LevelUnavailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.levelUnavailable, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      );
    }
    // LevelNotFound / LevelCorrupted (o cualquier otro error): terminal.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.levelLoadError, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.levelSelection,
            (_) => false,
          ),
          child: Text(l10n.backToLevels),
        ),
      ],
    );
  }
}
