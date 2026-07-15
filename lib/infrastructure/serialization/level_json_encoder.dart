import 'dart:convert';

import '../../domain/arrows/entities/arrow_board.dart';

/// Serializa un [ArrowBoard] al JSON arrow-path del wire contract
/// (CONTEXT-MAP raíz). Emite las claves del contrato para que el JSON sea
/// copiable tal cual al seed del back sin limpiar campos. [order] es un campo
/// opcional de curación/DB (la columna `order Int?` del back): se emite solo
/// cuando se provee — los consumidores del wire puro (app) no lo pasan. Los
/// campos temáticos ([palette] y `paintRole` por flecha, ADR 0004) también son
/// opcionales: ausentes conservan el JSON de campaña original.
class LevelJsonEncoder {
  const LevelJsonEncoder();

  Map<String, Object?> toMap({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
    int? order,
    Map<String, String>? palette,
  }) =>
      {
        'levelId': levelId,
        if (order != null) 'order': order,
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
              // Instrucciones de pintado (ADR 0004): solo se emite en flechas
              // temáticas; ausente en campaña conserva el JSON original.
              if (a.paintRole != null) 'paintRole': a.paintRole,
            },
        ],
        if (palette != null) 'palette': palette,
      };

  /// JSON con indent de 2 espacios y newline final: salida byte-estable para
  /// congelar candidatos en git (mismo input => mismos bytes).
  String encode({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
    int? order,
    Map<String, String>? palette,
  }) =>
      '${const JsonEncoder.withIndent('  ').convert(toMap(levelId: levelId, board: board, timeLimitSec: timeLimitSec, order: order, palette: palette))}\n';
}
