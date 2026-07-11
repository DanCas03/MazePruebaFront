import '../../domain/board/repositories/i_level_catalog.dart';
import '../../domain/board/value_objects/level_descriptor.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/board/value_objects/tier.dart';

/// Catálogo estático en memoria: los niveles curados que hoy sirve el cliente.
/// La curación define 15 niveles (3 por Tier × 5 Tiers); esta lista es la fuente
/// de verdad mientras no exista el endpoint de catálogo.
///
/// Escalar a 30+ niveles = subir [levelCount] (o servirlos desde la API con otra
/// implementación de `ILevelCatalog`): la pantalla de selección no cambia.
class StaticLevelCatalog implements ILevelCatalog {
  /// Cantidad de niveles curados. Múltiplo de `Tier.levelsPerTier` para que los
  /// Tiers queden completos.
  static const int levelCount = Tier.levelsPerTier * 5; // 15

  const StaticLevelCatalog();

  @override
  Future<List<LevelDescriptor>> getCatalog() async {
    return List<LevelDescriptor>.generate(levelCount, (i) {
      final number = i + 1; // ids 1-based, coherentes con LevelId.number
      return LevelDescriptor(
        levelId: LevelId('$number'),
        tier: Tier.forLevelNumber(number),
      );
    });
  }
}
