import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/level_catalog_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Argumentos de la ruta de victoria. Transporta el [levelId] (para calcular el
/// siguiente del Catálogo) y las métricas ya evaluadas por el `GameController`
/// (front#16): [moves], [score] y [stars] (1–3). La pantalla no calcula nada.
typedef VictoryArgs = ({LevelId levelId, int moves, int score, int stars});

/// Pantalla de victoria. El "siguiente nivel" lo dicta el Catálogo
/// (levelCatalogProvider): next = ids[indexOf(actual) + 1]. En el último nivel se
/// oculta el CTA y aparece la felicitación de campaña completada. Sin pantalla
/// nueva. Vista pasiva: recibe [VictoryArgs] via `ModalRoute`.
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

    // Orden de juego del Catálogo; el siguiente nivel es el posterior en la lista.
    final ids = ref.watch(levelCatalogProvider).valueOrNull ?? const <LevelId>[];
    final index = args == null ? -1 : ids.indexOf(args.levelId);
    final nextId = (index >= 0 && index + 1 < ids.length) ? ids[index + 1] : null;
    final isLastLevel = index >= 0 && index == ids.length - 1;

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
              // Siguiente nivel dictado por el Catálogo; en el último, felicitación.
              if (nextId != null)
                FilledButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    AppRouter.game,
                    arguments: nextId,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor:
                        isDark ? AppColors.background : AppColors.lightSurface,
                  ),
                  child: Text(l10n.nextLevel),
                )
              else if (isLastLevel)
                Text(
                  l10n.campaignComplete,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppColors.success),
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
