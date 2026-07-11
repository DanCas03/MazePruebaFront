import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Argumentos de la ruta de victoria. Transporta el [levelId] (para el CTA
/// "Next Level") y las métricas ya evaluadas por el `GameController` al ganar
/// (front#16): [moves], [score] y [stars] (1–3). Espeja el estilo de
/// `DefeatArgs` (primitivos): la pantalla no calcula nada, solo los pinta.
typedef VictoryArgs = ({LevelId levelId, int moves, int score, int stars});

/// Pantalla de victoria (enunciado 5.1.6): muestra las estrellas (1–3) y el
/// puntaje obtenidos, y ofrece continuar al siguiente nivel o volver al
/// selector. Vista pasiva: recibe [VictoryArgs] ya calculados via `ModalRoute`.
class VictoryScreen extends StatelessWidget {
  const VictoryScreen({super.key});

  static const int _maxStars = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as VictoryArgs?;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    final starCount = args?.stars ?? 0;
    final score = args?.score ?? 0;
    final moves = args?.moves ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.victoryTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 24),
              // Estrellas dinámicas: `starCount` llenas y el resto atenuadas.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _maxStars,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star,
                      size: 56,
                      color: i < starCount ? AppColors.success : muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.victoryScore(score),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark
                      ? AppColors.onBackground
                      : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.victoryMoves(moves),
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 48),
              FilledButton(
                // Requiere el nivel actual para calcular el siguiente; sin args
                // el CTA se deshabilita (igual criterio que DefeatScreen).
                onPressed: args == null
                    ? null
                    : () => Navigator.pushReplacementNamed(
                          context,
                          AppRouter.game,
                          arguments: LevelId('${args.levelId.number + 1}'),
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor:
                      isDark ? AppColors.background : AppColors.lightSurface,
                ),
                child: Text(l10n.nextLevel),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.levelSelection,
                  (_) => false,
                ),
                child: Text(l10n.backToLevels, style: TextStyle(color: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
