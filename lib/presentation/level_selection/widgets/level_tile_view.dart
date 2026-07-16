import 'package:flutter/material.dart';

import '../../../application/state/level_selection_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Celda de un nivel: posición en el Catálogo + fila de estrellas si está
/// desbloqueado; candado si está bloqueado. Los desbloqueados navegan a la
/// partida (tap) con el LevelId REAL y ofrecen el acceso al ranking del nivel
/// (front#17). Los bloqueados no hacen nada.
///
/// Widget compartido (front#100): lo consumen tanto el selector de campaña como
/// la sección temática, para que ambos pinten y naveguen la celda de forma
/// idéntica sin duplicar la lógica de tap/candado/estrellas.
class LevelTileView extends StatelessWidget {
  final LevelTile tile;
  const LevelTileView({super.key, required this.tile});

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
                  // La celda muestra la POSICIÓN (orden de juego); el id real
                  // del back es opaco y solo viaja en la navegación.
                  '${tile.position}',
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

    // Desbloqueado: el tap juega el nivel; el icono de ranking (front#17)
    // superpuesto arriba a la derecha lleva a su leaderboard sin robar el tap.
    return Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              AppRouter.game,
              arguments: tile.levelId,
            ),
            borderRadius: BorderRadius.circular(12),
            child: panel,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.leaderboard, size: 18),
            tooltip: AppLocalizations.of(context).viewLeaderboard,
            color: onBackground,
            onPressed: () => Navigator.pushNamed(
              context,
              AppRouter.leaderboard,
              arguments: tile.levelId,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cuadrícula de 3 columnas de celdas de nivel. Compartida (front#100) por el
/// bloque temático y por cualquier sección que solo necesite pintar tiles.
class LevelTileGrid extends StatelessWidget {
  final List<LevelTile> tiles;
  const LevelTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final tile in tiles) LevelTileView(tile: tile),
      ],
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
