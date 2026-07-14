import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/state/generated_game_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/seed_chip.dart';

/// Argumentos de la ruta post-partida del flujo generado: solo el resultado
/// ([won]) y los [moves] del run. Deliberadamente SIN score/stars/levelId — un
/// tablero generado no puntúa. La semilla y la config para las acciones se leen
/// del controlador vivo (no autoDispose), no viajan por la ruta.
typedef GeneratedResultArgs = ({bool won, int moves});

/// Pantalla post-partida del flujo GENERADO (front#37). Sin Score, sin Stars y
/// sin "Siguiente nivel". Muestra la semilla final (copiable) y las cuatro
/// acciones obligatorias:
///   - "Otro tablero": misma config, nueva semilla.
///   - "Repetir": misma semilla y config (tablero idéntico).
///   - "Cambiar parámetros": vuelve al configurador.
///   - "Salir": vuelve al Home.
///
/// Las dos primeras piden al controlador regenerar ANTES de navegar, para que
/// la pantalla de juego encuentre el tablero ya montado.
class GeneratedResultScreen extends ConsumerWidget {
  const GeneratedResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as GeneratedResultArgs?;
    final won = args?.won ?? false;
    final moves = args?.moves ?? 0;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    // Observa el estado para reconstruir si el tablero se (re)monta mientras la
    // pantalla está viva; la semilla se lee del controlador vivo (no viaja por
    // la ruta). En el flujo real ya está montada al entrar aquí.
    ref.watch(generatedGameControllerProvider);
    final notifier = ref.read(generatedGameControllerProvider.notifier);
    final seed = notifier.currentSeed;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.check_circle_outline : Icons.sentiment_dissatisfied,
                  size: 80,
                  color: won ? AppColors.success : AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  won ? l10n.generatedClearedTitle : l10n.generatedLostTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: won ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.gameMoves(moves),
                  style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                ),
                const SizedBox(height: 24),
                // Semilla final destacada + copiado (la única "métrica" que
                // importa en un tablero generado: reproducirlo).
                if (seed != null) SeedChip(seed: seed),
                const SizedBox(height: 40),
                _ActionButton(
                  label: l10n.generatedAnotherBoard,
                  icon: Icons.casino_outlined,
                  filled: true,
                  color: primary,
                  onPressed: () {
                    notifier.anotherBoard();
                    Navigator.pushReplacementNamed(
                        context, AppRouter.generatedGame);
                  },
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label: l10n.generatedRepeat,
                  icon: Icons.replay,
                  color: primary,
                  onPressed: () {
                    notifier.repeat();
                    Navigator.pushReplacementNamed(
                        context, AppRouter.generatedGame);
                  },
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label: l10n.generatedChangeParams,
                  icon: Icons.tune,
                  color: primary,
                  onPressed: () => Navigator.pushReplacementNamed(
                      context, AppRouter.generate),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRouter.home,
                    (_) => false,
                  ),
                  icon: Icon(Icons.home_outlined, color: muted),
                  label: Text(l10n.generatedExit,
                      style: TextStyle(color: muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de acción de la post-partida: relleno (acción primaria) o contorneado
/// (secundarias), con ancho consistente para una columna alineada.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onFilled = isDark ? AppColors.background : AppColors.lightSurface;
    return SizedBox(
      width: 260,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: onFilled,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}
