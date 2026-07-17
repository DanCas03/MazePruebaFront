import 'dart:convert';

import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/game_core/value_objects/position.dart';

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
    int? maxErrors,
    Map<String, String>? palette,
    Map<String, Set<Position>>? silhouette,
  }) =>
      {
        'levelId': levelId,
        if (order != null) 'order': order,
        'cols': board.cols,
        'rows': board.rows,
        if (timeLimitSec != null) 'timeLimitSec': timeLimitSec,
        // Presupuesto de errores por nivel (front#83): opcional como
        // timeLimitSec — solo se emite cuando se provee (ausente conserva el
        // JSON original y el default del dominio al decodear).
        if (maxErrors != null) 'maxErrors': maxErrors,
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
        // Silueta temática (#118): solo se emite cuando se provee; ausente en
        // campaña conserva el JSON original. Cada región se serializa
        // ordenada row-major (row, luego col) para que el orden de un Set
        // (no determinista) no rompa la salida byte-estable.
        ...(silhouette != null
            ? {
                'silhouette': {
                  for (final e in silhouette.entries)
                    e.key: (e.value.toList()
                          ..sort((a, b) =>
                              a.row != b.row ? a.row - b.row : a.col - b.col))
                        .map((p) => [p.row, p.col])
                        .toList(),
                },
              }
            : {}),
      };

  /// JSON con indent de 2 espacios y newline final: salida byte-estable para
  /// congelar candidatos en git (mismo input => mismos bytes).
  String encode({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
    int? order,
    int? maxErrors,
    Map<String, String>? palette,
    Map<String, Set<Position>>? silhouette,
  }) =>
      '${const JsonEncoder.withIndent('  ').convert(toMap(levelId: levelId, board: board, timeLimitSec: timeLimitSec, order: order, maxErrors: maxErrors, palette: palette, silhouette: silhouette))}\n';
}
