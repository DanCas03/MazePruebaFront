import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../providers/level_selection_provider.dart';
import 'widgets/level_tile_view.dart';

/// Modo hexagonal (front#127, ADR-0007 D6): pantalla propia para las fichas
/// libres de la sección `hex` del catálogo. Espejo del patrón temático
/// (front#100): consume el MISMO estado resuelto (`levelSelectionControllerProvider`)
/// y pinta solo su bloque `hexTiles` — todas jugables desde el inicio, sin
/// candados ni orden. Navega a la partida estándar con el LevelId REAL; el
/// score fluye al leaderboard general por la tubería existente, sin cambios.
///
/// Se empuja SOBRE Home: el `leading` implícito del AppBar garantiza la vuelta
/// al menú principal (front#96/#103).
class HexSelectionScreen extends ConsumerWidget {
  const HexSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final sections = ref.watch(levelSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hexSection),
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
        data: (view) => view.hexTiles.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.hexEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [LevelTileGrid(tiles: view.hexTiles)],
              ),
      ),
    );
  }
}
