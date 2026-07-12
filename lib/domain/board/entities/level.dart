import 'package:equatable/equatable.dart';

import '../../arrows/entities/arrow_board.dart';
import '../../core/exceptions/invalid_level_exception.dart';
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

  Level({
    required this.id,
    required this.board,
    this.timeLimitSec,
  }) {
    if (board.arrows.isEmpty) {
      throw const InvalidLevelException('a level must have at least one arrow');
    }
    final limit = timeLimitSec;
    if (limit != null && limit <= 0) {
      throw InvalidLevelException('timeLimitSec must be > 0, got $limit');
    }
  }

  @override
  List<Object?> get props => [id, board, timeLimitSec];
}
