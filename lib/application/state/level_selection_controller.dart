import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/services/tier_gating.dart';
import '../../domain/board/value_objects/catalog_entry.dart';
import '../../domain/board/value_objects/level_descriptor.dart';
import '../../domain/board/value_objects/level_progress.dart';
import '../../domain/board/value_objects/level_section.dart';
import '../../domain/board/value_objects/tier.dart';
import '../providers/level_catalog_provider.dart';
import 'level_selection_state.dart';

// El provider se compone en main/ (DI) o se sobreescribe en tests; la fábrica
// por defecto falla explícitamente para no acoplar este archivo a impls
// concretas (DIP), igual que gameControllerProvider.
final levelSelectionControllerProvider =
    AsyncNotifierProvider<LevelSelectionController, CatalogView>(
  () => throw UnimplementedError(
    'levelSelectionControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva (Riverpod) de la pantalla de selección: compone el Catálogo
/// remoto y el progreso local en un [CatalogView] con dos bloques ya resueltos:
/// la campaña por Tier (con estrellas y gating) y los niveles temáticos como
/// celdas sueltas (sin Tier ni bloqueos). El `AsyncValue` que envuelve el estado
/// cubre loading/error de forma sellada, sin necesidad de un estado propio.
///
/// El Catálogo se lee de `levelCatalogProvider` (front#8) vía `watch`: la lista
/// se descarga UNA vez por sesión (y dispara el prefetch), las recomposiciones
/// por entrada a la pantalla solo releen el progreso local, y un `refresh()` del
/// Catálogo (retry de la UI) recompone también este estado.
class LevelSelectionController extends AsyncNotifier<CatalogView> {
  final ILevelProgressRepository _progress;
  final TierGating _gating;

  LevelSelectionController(this._progress, this._gating);

  @override
  Future<CatalogView> build() async {
    final entries = await ref.watch(levelCatalogProvider.future);

    // Separa campaña (Tier + gating) de temáticos (sin gating). El Tier de la
    // campaña se deriva de la POSICIÓN ENTRE LOS NIVELES DE CAMPAÑA, no de la
    // posición absoluta: así intercalar temáticos no desplaza los Tiers. El id
    // del back es opaco: nunca se usa para aritmética (glosario CONTEXT.md).
    final campaignEntries =
        entries.where((e) => e.section == LevelSection.campaign).toList();
    final themedEntries =
        entries.where((e) => e.section == LevelSection.themed).toList();
    final hexEntries =
        entries.where((e) => e.section == LevelSection.hex).toList();

    final catalog = [
      for (var i = 0; i < campaignEntries.length; i++)
        LevelDescriptor(
          levelId: campaignEntries[i].id,
          tier: Tier.forLevelNumber(i + 1),
        ),
    ];
    final progress = await _progress.getAll();

    return CatalogView(
      campaignTiers: _sectionsFrom(catalog, progress),
      themedTiles: _freeTilesFrom(themedEntries, progress),
      hexTiles: _freeTilesFrom(hexEntries, progress),
    );
  }

  // La pantalla fuerza la recomposición al entrar con
  // `ref.invalidate(levelSelectionControllerProvider)` (ver
  // `LevelSelectionScreen`), de modo que `build()` vuelve a leer el progreso en
  // cada visita; el Catálogo ya resuelto se reutiliza (no re-descarga).

  // Estrellas ganadas por id (bestStars). Compartido por campaña y temáticos:
  // ambos bloques puntúan y persisten igual; solo difieren en Tier/gating.
  Map<String, int> _starsById(List<LevelProgress> progress) => {
        for (final p in progress)
          if (p.bestStars != null) p.levelId.value: p.bestStars!,
      };

  List<TierSection> _sectionsFrom(
    List<LevelDescriptor> catalog,
    List<LevelProgress> progress,
  ) {
    final unlocked = _gating.unlockedTiers(catalog, progress);
    final starsById = _starsById(progress);

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

  // Fichas "libres" de un bloque sin gating (temáticos y hex, ADR-0007 D6): sin
  // Tier ni bloqueos, con posición 1-based DENTRO del propio bloque y las
  // estrellas ganadas si las hay. Un único helper para ambas colecciones evita
  // dos copias que se separen por accidente (DRY).
  List<LevelTile> _freeTilesFrom(
    List<CatalogEntry> entries,
    List<LevelProgress> progress,
  ) {
    final starsById = _starsById(progress);
    return [
      for (var i = 0; i < entries.length; i++)
        LevelTile(
          levelId: entries[i].id,
          position: i + 1,
          stars: starsById[entries[i].id.value] ?? 0,
          locked: false, // sin gating por Tier: siempre jugables.
        ),
    ];
  }
}
