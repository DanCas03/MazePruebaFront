import 'package:equatable/equatable.dart';

import '../../arrows/entities/arrow_board.dart';
import '../../core/exceptions/invalid_direction_exception.dart';
import '../../core/exceptions/invalid_level_exception.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/strike_count.dart';
import '../value_objects/level_id.dart';

/// Nivel oficial de la campaña, servido por el back (wire contract, CONTEXT-MAP).
/// VO inmutable: identidad ([id]), tablero jugable ([board]) y límite de tiempo
/// opcional ([timeLimitSec], segundos). Invariantes en el constructor: un nivel
/// oficial vacío no es jugable (board con >= 1 flecha) y, si hay límite, debe
/// ser > 0. Su violación es un dato corrupto → excepción de dominio.
class Level extends Equatable {
  final LevelId id;
  final ArrowBoard board;
  final int? timeLimitSec;

  /// Instrucciones de pintado (ADR 0004): paleta rol→hex servida por niveles
  /// temáticos. Dato OPACO — el dominio no valida ni interpreta los colores; la
  /// solubilidad y la mecánica lo ignoran. Nulo en campaña. Lo consume el seam
  /// de color en presentación, que resuelve `Arrow.paintRole` contra esta paleta
  /// (front#67). Espejo de la decisión del back (back#31).
  final Map<String, String>? palette;

  /// Presupuesto de errores del nivel (front#83): cuántos choques admite antes
  /// de perder. El HUD lo muestra como un contador DESCENDENTE. Opcional en el
  /// wire (aditivo/tolerante): ausente ⇒ [StrikeCount.defaultMax], que preserva
  /// la dificultad actual de los niveles que aún no lo declaran.
  final int maxErrors;

  /// Silueta temática (#118): mapa rol→celdas del fill que define la forma
  /// jugable de niveles temáticos (corazón, carita feliz...). Nula en
  /// campaña. Invariantes si está presente: no vacía, toda celda dentro de la
  /// caja `cols×rows` del board (frame, no existencia en el espacio — ver
  /// `BoundingBox.contains`), y toda celda de toda flecha del board pertenece
  /// a la unión de sus regiones — el tablero jugable nunca desborda la
  /// silueta. Sienta la base del decoder y del seam de montaje que la
  /// consumirán (front#119+).
  final Map<String, Set<Position>>? silhouette;

  Level({
    required this.id,
    required this.board,
    this.timeLimitSec,
    this.palette,
    this.maxErrors = StrikeCount.defaultMax,
    this.silhouette,
  }) {
    if (board.arrows.isEmpty) {
      throw const InvalidLevelException('a level must have at least one arrow');
    }
    // Invariante ADR-0007 D3: toda flecha declara una dirección válida en el
    // espacio del tablero. Datos corruptos del wire => excepción de dominio.
    final spaceDirections = board.space.directions.toSet();
    for (final arrow in board.arrows) {
      if (!spaceDirections.contains(arrow.headDirection)) {
        throw InvalidDirectionException(
            'arrow ${arrow.id} headDirection ${arrow.headDirection} '
            'no es válida en el espacio del tablero');
      }
    }
    final limit = timeLimitSec;
    if (limit != null && limit <= 0) {
      throw InvalidLevelException('timeLimitSec must be > 0, got $limit');
    }
    if (maxErrors <= 0) {
      throw InvalidLevelException('maxErrors must be > 0, got $maxErrors');
    }
    final regions = silhouette;
    if (regions != null) {
      final union = silhouetteUnion!;
      if (regions.isEmpty || union.isEmpty) {
        throw const InvalidLevelException(
            'silhouette must have at least one region with at least one cell');
      }
      final bounds = board.space.bounds;
      for (final cell in union) {
        if (!bounds.contains(cell)) {
          throw InvalidLevelException(
              'silhouette cell $cell falls outside the board bounds');
        }
      }
      for (final arrow in board.arrows) {
        for (final cell in arrow.cells) {
          if (!union.contains(cell)) {
            throw InvalidLevelException(
                'arrow ${arrow.id} cell $cell falls outside the silhouette union');
          }
        }
      }
    }
  }

  /// Unión de todas las regiones de [silhouette]. `null` si no hay silueta
  /// (campaña).
  Set<Position>? get silhouetteUnion => silhouette?.values
      .fold<Set<Position>>(<Position>{}, (acc, cells) => acc..addAll(cells));

  @override
  List<Object?> get props =>
      [id, board, timeLimitSec, palette, maxErrors, silhouette];
}
