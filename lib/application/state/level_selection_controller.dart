import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/board/repositories/i_level_catalog.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/services/tier_gating.dart';
import '../../domain/board/value_objects/level_descriptor.dart';
import '../../domain/board/value_objects/level_progress.dart';
import '../../domain/board/value_objects/tier.dart';
import 'level_selection_state.dart';

// El provider se compone en main/ (DI) o se sobreescribe en tests; la fábrica
// por defecto falla explícitamente para no acoplar este archivo a impls
// concretas (DIP), igual que gameControllerProvider.
final levelSelectionControllerProvider =
    AsyncNotifierProvider<LevelSelectionController, List<TierSection>>(
  () => throw UnimplementedError(
    'levelSelectionControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva (Riverpod) de la pantalla de selección: compone el catálogo
/// y el progreso en secciones por Tier con estrellas y estado de bloqueo ya
/// resueltos. El `AsyncValue` que envuelve el estado cubre loading/error de
/// forma sellada, sin necesidad de un estado propio.
class LevelSelectionController extends AsyncNotifier<List<TierSection>> {
  final ILevelCatalog _catalog;
  final ILevelProgressRepository _progress;
  final TierGating _gating;

  LevelSelectionController(this._catalog, this._progress, this._gating);

  @override
  Future<List<TierSection>> build() async {
    final catalog = await _catalog.getCatalog();
    final progress = await _progress.getAll();
    return _sectionsFrom(catalog, progress);
  }

  // La pantalla fuerza la recomposición al entrar con
  // `ref.invalidate(levelSelectionControllerProvider)` (ver
  // `LevelSelectionScreen`), de modo que `build()` vuelve a leer catálogo +
  // progreso en cada visita sin necesidad de un método de refresh propio.

  List<TierSection> _sectionsFrom(
    List<LevelDescriptor> catalog,
    List<LevelProgress> progress,
  ) {
    final unlocked = _gating.unlockedTiers(catalog, progress);
    final starsById = <String, int>{
      for (final p in progress)
        if (p.bestStars != null) p.levelId.value: p.bestStars!,
    };

    // Agrupa por Tier conservando el orden de aparición del catálogo.
    final byTier = <Tier, List<LevelTile>>{};
    for (final d in catalog) {
      byTier.putIfAbsent(d.tier, () => <LevelTile>[]).add(
            LevelTile(
              levelId: d.levelId,
              stars: starsById[d.levelId.value] ?? 0,
              locked: !unlocked.contains(d.tier),
            ),
          );
    }

    final tiers = byTier.keys.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));
    return [for (final t in tiers) TierSection(tier: t, tiles: byTier[t]!)];
  }
}
