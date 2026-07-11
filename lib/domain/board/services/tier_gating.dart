import '../value_objects/level_descriptor.dart';
import '../value_objects/level_progress.dart';
import '../value_objects/tier.dart';

/// Regla de gating por Tier (dominio puro, sin Flutter): decide qué Tiers están
/// desbloqueados a partir del catálogo y del progreso.
///
/// Regla acordada (issue #20): el primer Tier siempre está abierto; un Tier `T`
/// se desbloquea cuando **todos** los niveles de los Tiers de menor rango están
/// completados. Al ser secuencial, esto equivale a "el Tier anterior completado"
/// una vez que se avanza en orden, pero se expresa sobre los niveles de menor
/// rango para ser robusto ante catálogos con huecos o desordenados.
class TierGating {
  const TierGating();

  /// El conjunto de Tiers desbloqueados dado el [catalog] y el [progress].
  Set<Tier> unlockedTiers(
    List<LevelDescriptor> catalog,
    List<LevelProgress> progress,
  ) {
    final completedIds = progress
        .where((p) => p.completed)
        .map((p) => p.levelId.value)
        .toSet();

    final tiersPresent = catalog.map((d) => d.tier).toSet();

    return tiersPresent
        .where((tier) => _lowerTiersComplete(tier, catalog, completedIds))
        .toSet();
  }

  /// Si el nivel [descriptor] es jugable: su Tier está desbloqueado.
  bool isLevelUnlocked(
    LevelDescriptor descriptor,
    List<LevelDescriptor> catalog,
    List<LevelProgress> progress,
  ) =>
      unlockedTiers(catalog, progress).contains(descriptor.tier);

  // Todos los niveles del catálogo con rango de Tier estrictamente menor están
  // completados. Vacuamente cierto para el Tier de menor rango (sin niveles
  // previos) → el primer Tier siempre abre.
  bool _lowerTiersComplete(
    Tier tier,
    List<LevelDescriptor> catalog,
    Set<String> completedIds,
  ) =>
      catalog
          .where((d) => d.tier.rank < tier.rank)
          .every((d) => completedIds.contains(d.levelId.value));
}
