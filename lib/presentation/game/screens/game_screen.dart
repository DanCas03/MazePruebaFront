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

  // #102: elegibilidad del auto-solver (toda la campaña + temáticos), fuente
  // única compartida con el controlador. Decide si se pinta el botón en este
  // nivel.
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

  // #102: el auto-solver es explícito y destructivo para el intento en curso,
  // así que exige confirmación antes de arrancar. Cancelar no toca el juego;
  // confirmar dispara playHint() (reproduce la Solución y reinicia el nivel,
  // sin puntuar). Async separado del onPressed del botón para que la UI no
  // bloquee mientras el diálogo está abierto.
  Future<void> _confirmAndAutoSolve(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.autoSolveConfirmTitle),
        content: Text(l10n.autoSolveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.autoSolveConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.autoSolveConfirmAction),
          ),
        ],
      ),
    );
    // `mounted`: el diálogo pudo cerrarse por una navegación que ya desmontó
    // esta pantalla (p. ej. system-back) mientras estaba abierto.
    if (confirmed == true && mounted) {
      ref.read(gameControllerProvider.notifier).playHint();
    }
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
        // #102 (evolución de #32): el auto-solver falló o expiró (el back no
        // respondió a tiempo). La partida queda intacta; solo avisamos con un
        // snackbar no intrusivo.
        if (state.hintErrorNonce > prevState.hintErrorNonce) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.autoSolveError)));
        }
      }

      // front#98: navegación terminal IDEMPOTENTE. Se dispara solo en el BORDE
      // de transición hacia el estado terminal (`prev is! GameWon`), no ante
      // "el estado ES GameWon". GameState no tiene igualdad por valor, así que
      // cada re-emisión del async value estando ya en victoria (p. ej. tras el
      // POST del score) es una instancia nueva; sin la guarda de borde el
      // listener re-ejecutaría pushReplacement y apilaría una segunda pantalla.
      // El mismo blindaje aplica a la transición simétrica GameLost → derrota.
      //
      // front#98 (refuerzo): INVARIANTE POR NIVEL. El provider NO es autoDispose,
      // así que tras ganar y volver al menú el estado queda en GameWon del nivel
      // anterior; al entrar a OTRO nivel esta pantalla monta sobre ese GameWon
      // rezagado. Exigimos `state.levelId == widget.levelId`: una pantalla solo
      // navega a la victoria de SU PROPIO nivel, nunca a la de otro —blinda el
      // síntoma "al entrar a un nivel reaparece la victoria del anterior" sea
      // cual sea el momento en que el listener observe el estado rezagado.
      if (state is GameWon &&
          prevState is! GameWon &&
          state.levelId == widget.levelId) {
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
      } else if (state is GameLost && prevState is! GameLost) {
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
          // Presupuesto de errores del nivel (front#83): contador DESCENDENTE de
          // choques restantes. Presente durante toda la partida (cada nivel tiene
          // un máximo); al llegar a 0 se pierde.
          ...asyncState.maybeWhen(
            data: (s) => s is GamePlaying
                ? [
                    _ErrorsChip(
                      remaining: s.strikes.remaining,
                      color: onSurface,
                      tooltip: l10n.errorsLeft,
                    )
                  ]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
          // Cuenta atrás de los niveles con límite (front#11); ausente si el
          // nivel no está cronometrado.
          ...asyncState.maybeWhen(
            data: (s) => s is GamePlaying && s.remainingSeconds != null
                ? [_CountdownChip(seconds: s.remainingSeconds!, color: onSurface)]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
          // #102 (evolución de #32): botón de auto-solver, en TODO nivel de
          // campaña (elegibilidad abierta) durante el juego. El icono se
          // transforma en un spinner mientras la solución viaja (mitiga dobles
          // clics) y queda inerte durante la reproducción.
          ...asyncState.maybeWhen(
            data: (s) => s is GamePlaying &&
                    _hintPolicy.isEligible(widget.levelId,
                        themed: s.palette != null)
                ? [
                    _AutoSolveButton(
                      loading: s.hintLoading,
                      playing: s.hintPlaying,
                      color: accent,
                      tooltip: l10n.autoSolveTooltip,
                      onPressed: () => _confirmAndAutoSolve(l10n),
                    )
                  ]
                : const <Widget>[],
            orElse: () => const <Widget>[],
          ),
          IconButton(
            icon: Icon(Icons.undo, color: accent),
            // Undo deshabilitado mientras el auto-solver está activo (#102).
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

/// Presupuesto de errores restantes en la AppBar (front#83): un corazón y el
/// número de choques que aún admite el nivel. Desciende con cada error; a 0 se
/// pierde. Espeja el patrón visual de [_CountdownChip].
class _ErrorsChip extends StatelessWidget {
  final int remaining;
  final Color color;
  final String tooltip;
  const _ErrorsChip({
    required this.remaining,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, color: color, size: 18),
            const SizedBox(width: 4),
            Text('$remaining', style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Botón del auto-solver (#102, evolución de la "pista" #32) — icono de vara
/// mágica en vez de la bombilla vieja para que se lea como "resuélvelo por
/// mí", no como una ayuda vaga. Tres aspectos según el sub-estado:
/// - inactivo: pulsable, dispara [onPressed] (que en `GameScreen` abre la
///   confirmación antes de reproducir — el progreso del intento se pierde).
/// - cargando: un spinner sustituye al icono y el botón queda inerte, para
///   mitigar dobles clics mientras la solución viaja por HTTP.
/// - reproduciendo: icono relleno y atenuado, inerte (la demo está en curso).
class _AutoSolveButton extends StatelessWidget {
  final bool loading;
  final bool playing;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _AutoSolveButton({
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
        icon: Icon(Icons.auto_fix_high, color: color.withValues(alpha: 0.38)),
        tooltip: tooltip,
        onPressed: null, // inerte durante la reproducción de la solución
      );
    }
    return IconButton(
      icon: Icon(Icons.auto_fix_high, color: color),
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
          // Conserva Home bajo la selección de niveles para que no desaparezca
          // la flecha de retorno del AppBar (política centralizada en AppRouter,
          // front#103).
          onPressed: () => AppRouter.backToLevels(context),
          child: Text(l10n.backToLevels),
        ),
      ],
    );
  }
}
