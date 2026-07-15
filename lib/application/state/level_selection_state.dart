import 'package:equatable/equatable.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../domain/board/value_objects/tier.dart';

/// View model de una celda de la cuadrícula de selección: qué nivel es, cuántas
/// estrellas tiene ganadas (0..3; 0 = aún sin ★ registradas) y si está bloqueado
/// por el gating de Tier. Es dato de presentación ya resuelto: la UI solo pinta.
class LevelTile extends Equatable {
  final LevelId levelId;

  /// Posición 1-based del nivel en el Catálogo (su orden de juego). Es lo que
  /// la celda MUESTRA: el id real del back es opaco (p. ej. "level-01") y solo
  /// se usa para navegar/puntuar, nunca como etiqueta ni para aritmética.
  final int position;

  /// Estrellas ganadas, 0..3. 0 cubre el caso "completado pero sin ★ aún" y el
  /// "no jugado": la UI muestra 0 estrellas llenas sin romperse.
  final int stars;

  /// Bloqueado por gating (su Tier no está desbloqueado). No navega.
  final bool locked;

  const LevelTile({
    required this.levelId,
    required this.position,
    required this.stars,
    required this.locked,
  });

  @override
  List<Object?> get props => [levelId, position, stars, locked];
}

/// View model de una sección de la pantalla: un Tier con sus celdas. Las
/// secciones por Tier son, a la vez, la agrupación visual por dificultad.
class TierSection extends Equatable {
  final Tier tier;
  final List<LevelTile> tiles;

  const TierSection({required this.tier, required this.tiles});

  @override
  List<Object?> get props => [tier, tiles];
}

/// Estado ya resuelto de la pantalla de selección: la campaña, agrupada en
/// [campaignTiers] (con Tier + gating + estrellas), y los niveles temáticos como
/// [themedTiles] (SIN Tier, SIN gating, nunca bloqueados). Modelar el catálogo
/// como este agregado mantiene ambos bloques independientes: intercalar niveles
/// temáticos no desplaza los Tiers de campaña, y un catálogo sin temáticos deja
/// [themedTiles] vacío (la pantalla se ve idéntica a antes).
class CatalogView extends Equatable {
  final List<TierSection> campaignTiers;
  final List<LevelTile> themedTiles;

  const CatalogView({required this.campaignTiers, required this.themedTiles});

  @override
  List<Object?> get props => [campaignTiers, themedTiles];
}
