import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/services/tier_gating.dart';
import '../../domain/board/value_objects/level_descriptor.dart';
import '../../domain/board/value_objects/level_progress.dart';
import '../../domain/board/value_objects/tier.dart';
import '../providers/level_catalog_provider.dart';
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

/// Fachada reactiva (Riverpod) de la pantalla de selección: compone el Catálogo
/// remoto y el progreso local en secciones por Tier con estrellas y estado de
/// bloqueo ya resueltos. El `AsyncValue` que envuelve el estado cubre
/// loading/error de forma sellada, sin necesidad de un estado propio.
///
/// El Catálogo se lee de `levelCatalogProvider` (front#8) vía `watch`: la lista
/// se descarga UNA vez por sesión (y dispara el prefetch de campaña), las
/// recomposiciones por entrada a la pantalla solo releen el progreso local, y
/// un `refresh()` del Catálogo (retry de la UI) recompone también este estado.
class LevelSelectionController extends AsyncNotifier<List<TierSection>> {
  final ILevelProgressRepository _progress;
  final TierGating _gating;

  LevelSelectionController(this._progress, this._gating);

  @override
  Future<List<TierSection>> build() async {
    final ids = await ref.watch(levelCatalogProvider.future);
    // El Tier se deriva de la POSICIÓN en el Catálogo (su orden ES el orden de
    // juego); el id del back es opaco: nunca se usa para aritmética (glosario
    // CONTEXT.md), solo para navegar y puntuar.
    final catalog = [
      for (var i = 0; i < ids.length; i++)
        LevelDescriptor(levelId: ids[i], tier: Tier.forLevelNumber(i + 1)),
    ];
    final progress = await _progress.getAll();
    return _sectionsFrom(catalog, progress);
  }

  // La pantalla fuerza la recomposición al entrar con
  // `ref.invalidate(levelSelectionControllerProvider)` (ver
  // `LevelSelectionScreen`), de modo que `build()` vuelve a leer el progreso en
  // cada visita; el Catálogo ya resuelto se reutiliza (no re-descarga).

  List<TierSection> _sectionsFrom(
    List<LevelDescriptor> catalog,
    List<LevelProgress> progress,
  ) {
    final unlocked = _gating.unlockedTiers(catalog, progress);
    final starsById = <String, int>{
      for (final p in progress)
        if (p.bestStars != null) p.levelId.value: p.bestStars!,
    };

    // Agrupa por Tier conservando el orden de aparición del catálogo; la
    // posición (i+1) es la etiqueta visible de la celda.
    final byTier = <Tier, List<LevelTile>>{};
    for (var i = 0; i < catalog.length; i++) {
      final d = catalog[i];
      byTier.putIfAbsent(d.tier, () => <LevelTile>[]).add(
            LevelTile(
              levelId: d.levelId,
              position: i + 1,
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
