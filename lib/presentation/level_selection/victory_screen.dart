import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/leaderboard_providers.dart';
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
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    // Reconciliación con el resultado CANÓNICO (ADR 0006): mientras el POST
    // /scores no responda (o si falla), se muestra el preview cliente de
    // GameWon; en cuanto resuelve, el reemplazo es silencioso (sin spinner,
    // decisión Q11).
    final canonical = ref.watch(canonicalResultProvider);
    final starCount = canonical?.stars.value ?? args?.stars ?? 0;
    final score = canonical?.score.value ?? args?.score ?? 0;
    final moves = args?.moves ?? 0;

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
              // "Qué sigue" lo decide el dominio (gating incluido): esta sección
              // solo pinta el outcome. Distingue loading/error/data explícitamente
              // (front#122) para que un fallo de red al resolverlo no deje el CTA
              // en blanco sin explicación — antes indistinguible de "cargando" o
              // "nivel temático, sin siguiente".
              _NextLevelSection(levelId: args?.levelId),
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

/// Resuelve y pinta el "qué sigue" (front#81) sin colapsar loading/error en el
/// mismo `null` que "sin siguiente" (temático o sin [levelId]): un fallo de red
/// al calcularlo muestra un mensaje con reintento en vez de dejar el hueco del
/// CTA en blanco, indistinguible de "está cargando" (regresión de #122).
class _NextLevelSection extends ConsumerWidget {
  final LevelId? levelId;
  const _NextLevelSection({required this.levelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = levelId;
    if (id == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return ref.watch(nextLevelOutcomeProvider(id)).when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => _NextLevelError(
            onRetry: () => ref.invalidate(nextLevelOutcomeProvider(id)),
          ),
          data: (outcome) => switch (outcome) {
            NextLevelUnlocked(:final levelId) => FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRouter.game,
                  arguments: levelId,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor:
                      isDark ? AppColors.background : AppColors.lightSurface,
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
            NotInCampaign() => const SizedBox.shrink(),
          },
        );
  }
}

/// Mensaje de "no se pudo calcular el siguiente nivel" con reintento — mismo
/// patrón que `_ProfileError` (account_panel.dart) y `_ErrorState`
/// (leaderboard_screen.dart): nunca un hueco vacío sin explicación.
class _NextLevelError extends StatelessWidget {
  final VoidCallback onRetry;
  const _NextLevelError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.nextLevelError,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
