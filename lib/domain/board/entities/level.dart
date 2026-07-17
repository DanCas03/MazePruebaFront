import 'package:equatable/equatable.dart';

import '../../arrows/entities/arrow_board.dart';
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

  /// Silueta de figura (front#114): rol→celdas de su región. En niveles
  /// temáticos define la MÁSCARA del tablero: el board se monta sobre un
  /// `MaskedSpace` cuyas celdas activas son la unión de estas celdas, así solo
  /// la figura existe (los cuadros fuera de ella no se ven) y el hit-testing y
  /// los carriles de salida operan sobre esa silueta. Nula en campaña.
  final Map<String, List<Position>>? silhouette;

  /// Presupuesto de errores del nivel (front#83): cuántos choques admite antes
  /// de perder. El HUD lo muestra como un contador DESCENDENTE. Opcional en el
  /// wire (aditivo/tolerante): ausente ⇒ [StrikeCount.defaultMax], que preserva
  /// la dificultad actual de los niveles que aún no lo declaran.
  final int maxErrors;

  Level({
    required this.id,
    required this.board,
    this.timeLimitSec,
    this.palette,
    this.silhouette,
    this.maxErrors = StrikeCount.defaultMax,
  }) {
    if (board.arrows.isEmpty) {
      throw const InvalidLevelException('a level must have at least one arrow');
    }
    final limit = timeLimitSec;
    if (limit != null && limit <= 0) {
      throw InvalidLevelException('timeLimitSec must be > 0, got $limit');
    }
    if (maxErrors <= 0) {
      throw InvalidLevelException('maxErrors must be > 0, got $maxErrors');
    }
  }

  @override
  List<Object?> get props => [id, board, timeLimitSec, palette, silhouette, maxErrors];
}
