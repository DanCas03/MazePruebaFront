import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/state/level_selection_state.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/tier.dart';
import '../../l10n/app_localizations.dart';
import '../providers/level_selection_provider.dart';

/// Selección de nivel: agrupa el catálogo por Tier (que es, a la vez, la
/// agrupación por dificultad), muestra las estrellas ganadas por nivel y bloquea
/// los niveles de Tiers aún no alcanzados. La lista y el estado de bloqueo los
/// resuelve `levelSelectionControllerProvider`; esta pantalla es pura
/// presentación.
class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    final sections = ref.watch(levelSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLevel),
        backgroundColor: surface,
      ),
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            l10n.levelsLoadError,
            style: TextStyle(color: muted),
          ),
        ),
        data: (tiers) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final section in tiers) _TierSectionView(section: section),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de dificultad + cuadrícula de niveles de un Tier.
class _TierSectionView extends StatelessWidget {
  final TierSection section;
  const _TierSectionView({required this.section});

  // Mapea los 5 Tiers de la rampa a las 3 etiquetas de dificultad del enunciado.
  static String _difficultyLabel(AppLocalizations l10n, Tier tier) =>
      switch (tier) {
        Tier.one || Tier.two => l10n.difficultyEasy,
        Tier.three => l10n.difficultyMedium,
        Tier.four || Tier.five => l10n.difficultyHard,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Row(
            children: [
              Text(
                l10n.tierLabel(section.tier.rank),
                style: TextStyle(
                  color: onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· ${_difficultyLabel(l10n, section.tier)}',
                style: TextStyle(color: muted, fontSize: 14),
              ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final tile in section.tiles) _LevelTileView(tile: tile),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Celda de un nivel: número + fila de estrellas si está desbloqueado; candado
/// si está bloqueado. Solo los desbloqueados navegan a la partida.
class _LevelTileView extends StatelessWidget {
  final LevelTile tile;
  const _LevelTileView({required this.tile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.lightGlassFill;
    final glassBorder =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    final panel = Container(
      key: ValueKey('level-tile-${tile.levelId.value}'),
      decoration: BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder),
      ),
      alignment: Alignment.center,
      child: tile.locked
          ? Icon(Icons.lock, color: muted, size: 26)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tile.levelId.value,
                  style: TextStyle(
                    color: onBackground,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                _StarRow(stars: tile.stars),
              ],
            ),
    );

    if (tile.locked) return panel; // bloqueado: no navega, sin ripple.

    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        AppRouter.game,
        arguments: tile.levelId,
      ),
      borderRadius: BorderRadius.circular(12),
      child: panel,
    );
  }
}

/// Tres ranuras de estrella; se llenan hasta [stars] (0..3).
class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  static const int _maxStars = 3;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.onSurfaceMuted
        : AppColors.lightOnSurfaceMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _maxStars; i++)
          Icon(
            i < stars ? Icons.star : Icons.star_border,
            size: 14,
            color: i < stars ? AppColors.victory : muted,
          ),
      ],
    );
  }
}
