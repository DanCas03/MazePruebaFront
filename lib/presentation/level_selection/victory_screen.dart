import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/next_level_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/services/campaign_progression.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Argumentos de la ruta de victoria. Transporta el [levelId] (para calcular el
/// siguiente del Catálogo) y las métricas ya evaluadas por el `GameController`
/// (front#16): [moves], [score] y [stars] (1–3). La pantalla no calcula nada.
typedef VictoryArgs = ({LevelId levelId, int moves, int score, int stars});

/// Pantalla de victoria. El "siguiente nivel" lo resuelve el dominio
/// (`CampaignProgression` vía `nextLevelOutcomeProvider`), que compone Catálogo +
/// progreso y RESPETA el gating por Tier (front#81): el CTA "Next Level" solo
/// aparece si el siguiente nivel de campaña está desbloqueado; si su Tier sigue
/// bloqueado se muestra el requisito en vez del botón (antes se ofrecía siempre
/// por pura adyacencia, saltándose el gating). En el último nivel de campaña
/// aparece la felicitación; un nivel TEMÁTICO no ofrece ninguna de las dos. Vista
/// pasiva: recibe [VictoryArgs] via `ModalRoute` y solo pinta el outcome.
class VictoryScreen extends ConsumerWidget {
  const VictoryScreen({super.key});

  static const int _maxStars = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // "Qué sigue" lo decide el dominio (gating incluido): la pantalla solo pinta
    // el outcome. Mientras el future resuelve —o sin args— no hay CTA (null).
    final outcome = args == null
        ? null
        : ref.watch(nextLevelOutcomeProvider(args.levelId)).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.victoryTitle,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: AppColors.success),
              ),
              const SizedBox(height: 24),
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
              // El outcome de dominio decide el paso: botón SOLO si el siguiente
              // Tier está abierto; si está bloqueado, el requisito; en el último,
              // la felicitación; para temáticos o mientras carga, nada.
              switch (outcome) {
                NextLevelUnlocked(:final levelId) => FilledButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRouter.game,
                      arguments: levelId,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: isDark
                          ? AppColors.background
                          : AppColors.lightSurface,
                    ),
                    child: Text(l10n.nextLevel),
                  ),
                CampaignComplete() => Text(
                    l10n.campaignComplete,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.success),
                  ),
                NextLevelLocked() => Text(
                    l10n.nextLevelLocked,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: muted),
                  ),
                NotInCampaign() || null => const SizedBox.shrink(),
              },
              const SizedBox(height: 8),
              TextButton(
                // Conserva Home bajo la selección de niveles para que la flecha
                // de retorno auto-implícita del AppBar siga visible al volver
                // (política centralizada en AppRouter, front#103).
                onPressed: () => AppRouter.backToLevels(context),
                child: Text(l10n.backToLevels, style: TextStyle(color: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
