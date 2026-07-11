import '../value_objects/level_descriptor.dart';

/// Puerto del catálogo de niveles: la fuente de la lista de niveles jugables,
/// ya ordenada y agrupada por Tier. La pantalla de selección la consume sin
/// conocer su origen.
///
/// La implementación de #20 es estática (los 15 niveles curados en memoria);
/// una implementación futura puede servir la lista desde la API (`GET /levels`)
/// sin que la UI ni el gating cambien (DIP + OCP).
abstract interface class ILevelCatalog {
  Future<List<LevelDescriptor>> getCatalog();
}
