import 'dart:convert';

import '../../domain/arrows/entities/arrow_board.dart';

/// Serializa un [ArrowBoard] al JSON arrow-path del wire contract
/// (CONTEXT-MAP raíz). Emite EXACTAMENTE las claves del contrato para que el
/// JSON sea copiable tal cual al seed del back sin limpiar campos.
class LevelJsonEncoder {
  const LevelJsonEncoder();

  Map<String, Object?> toMap({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
  }) =>
      {
        'levelId': levelId,
        'cols': board.cols,
        'rows': board.rows,
        if (timeLimitSec != null) 'timeLimitSec': timeLimitSec,
        'arrows': [
          for (final a in board.arrows)
            {
              'id': a.id.value,
              'headDir': a.headDirection.name,
              'cells': [
                for (final c in a.cells) [c.row, c.col],
              ],
            },
        ],
      };

  /// JSON con indent de 2 espacios y newline final: salida byte-estable para
  /// congelar candidatos en git (mismo input => mismos bytes).
  String encode({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
  }) =>
      '${const JsonEncoder.withIndent('  ').convert(toMap(levelId: levelId, board: board, timeLimitSec: timeLimitSec))}\n';
}
