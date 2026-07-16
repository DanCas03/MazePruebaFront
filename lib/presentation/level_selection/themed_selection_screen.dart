import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../providers/level_selection_provider.dart';
import 'widgets/level_tile_view.dart';

/// Sección temática (front#100): pantalla propia para los niveles temáticos,
/// alcanzable desde el menú principal en vez de vivir embebida al final del
/// selector de campaña. Consume el MISMO estado resuelto que el selector
/// (`levelSelectionControllerProvider`) y pinta solo su bloque `themedTiles`,
/// reutilizando el tile compartido — así el contenido temático vive en un solo
/// lugar y navega a la partida con el LevelId REAL igual que la campaña.
///
/// Se empuja SOBRE Home, de modo que el `leading` implícito del AppBar ofrece la
/// vuelta al menú principal (back path garantizado, ver front#96/#103).
class ThemedSelectionScreen extends ConsumerWidget {
  const ThemedSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final sections = ref.watch(levelSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.themedSection),
        backgroundColor: surface,
      ),
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.levelsLoadError, textAlign: TextAlign.center),
          ),
        ),
        data: (view) => view.themedTiles.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.themedEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [LevelTileGrid(tiles: view.themedTiles)],
              ),
      ),
    );
  }
}
