// tool/level_production/themed_producer.dart
//
// Producción PURA de un nivel temático (front#68/front#114): mask → regiones →
// `generateThemedFull` (determinista) → validar → medir cobertura → serializar.
// Sin IO ni argumentos de CLI — todo eso vive en `produce_themed.dart`
// (mismo reparto puro/CLI que candidate_producer.dart / produce.dart, front#65).
//
// La estrategia de cobertura (front#114): `generateThemedFull` pela la figura
// celda a celda con flechas rectas ≥2 y cubre ~100% de cada región de forma
// DETERMINISTA (sin semillas ni rng), así que ya no hay búsqueda por semillas.

import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

import 'mask_spec.dart';
import 'validation.dart';

/// Resultado de producir un nivel temático: el JSON listo para congelar, la
/// telemetría de cobertura para el manifiesto y una vista previa ANSI para
/// curación humana.
class ThemedResult {
  final String levelId;

  /// JSON arrow-path temático (salida del encoder), listo para escribir en
  /// `<levelId>.json`.
  final String json;

  /// role -> cobertura lograda en [0,1]: celdas de la región ocupadas por
  /// flechas de ese rol / celdas totales de la región.
  final Map<String, double> coveragePerRole;

  /// Siempre 0 desde front#114: la generación es determinista y sin semillas.
  /// Se conserva por compatibilidad con el manifiesto/CLI.
  final int seedUsed;
  final int placedArrows;

  /// true si TODAS las regiones quedaron a cobertura ~total (>= 99.9%).
  final bool allRegionsMetTarget;

  /// Grid ASCII coloreado (ANSI truecolor), `rows` líneas × `cols` chars:
  /// `█` = celda ocupada (color de su región), `░` = hueco de cobertura en la
  /// región (color tenue de la figura), espacio = fondo. Para curación humana.
  final String preview;

  const ThemedResult({
    required this.levelId,
    required this.json,
    required this.coveragePerRole,
    required this.seedUsed,
    required this.placedArrows,
    required this.allRegionsMetTarget,
    required this.preview,
  });
}

/// Produce un nivel temático solvable a partir de [mask] con
/// `generateThemedFull`: relleno ~100% de cada región, determinista.
///
/// - El tablero generado se valida con `validateCandidate`; si no es solvable
///   la excepción se propaga (fallo real de generación, no se enmascara).
/// - El JSON se emite SIN `order` ni `timeLimitSec`: temático v1 no tiene
///   límite de tiempo, y como el encoder omite campos null, la AUSENCIA de
///   `timeLimitSec` es la anotación de "sin límite".
///
/// [coverageTarget] y [seeds] se conservan en la firma por compatibilidad con
/// la CLI, pero se IGNORAN desde front#114: la generación es determinista
/// (sin rng) y cubre la figura casi por completo por construcción.
ThemedResult produceThemed(
  MaskSpec mask, {
  double coverageTarget = 0.9, // ignorado (front#114): cobertura ~total fija
  int maxPathLen = 4,
  Iterable<int> seeds = const [], // ignorado (front#114): sin rng
}) {
  final generator = GraphBoardGenerator();
  final levelId = 'themed-${mask.name}';

  // Orden detalle-primero (regiones pequeñas antes que grandes), conservado
  // por estabilidad de salida; generateThemedFull pela por grado celda a
  // celda, así que el orden de regiones ya no condiciona la cobertura.
  final orderedRegions = mask.regions.toList()
    ..sort((a, b) => a.cells.length.compareTo(b.cells.length));

  final regionSpecs = <ThemedRegionSpec>[
    for (final region in orderedRegions)
      ThemedRegionSpec(
        role: region.role,
        cells: region.cells,
        // generateThemedFull rellena la región completa; arrowCount solo
        // satisface el contrato del spec (no limita el relleno).
        arrowCount: region.cells.length,
        maxPathLen: maxPathLen,
      ),
  ];

  // Una sola llamada determinista (front#114): sin semillas ni mejor-vista.
  final ArrowBoard board = generator.generateThemedFull(
    cols: mask.cols,
    rows: mask.rows,
    regions: regionSpecs,
  );

  // Solvabilidad obligatoria: si el tablero no se vacía, es un fallo real de
  // generación y la excepción debe propagarse (no hay semillas que reintentar).
  validateCandidate(board);

  final coverage = _coveragePerRole(mask, board);

  return ThemedResult(
    levelId: levelId,
    json: const LevelJsonEncoder().encode(
      levelId: levelId,
      board: board,
      palette: mask.palette,
      // Silueta de figura (front#114): rol→TODAS las celdas de su región,
      // ordenadas por (fila, columna) para salida determinista. La consume el
      // render para rellenar la figura sin huecos; dato opaco (no afecta
      // solubilidad ni mecánica).
      silhouette: {
        for (final region in mask.regions)
          region.role: (region.cells.toList()
            ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col)),
      },
    ),
    coveragePerRole: coverage,
    seedUsed: 0, // sin semillas desde front#114 (generación determinista)
    placedArrows: board.arrows.length,
    allRegionsMetTarget: coverage.values.every((c) => c >= 0.999),
    preview: _renderPreview(mask, board),
  );
}

/// role -> celdas de su región ocupadas por flechas de ese rol / celdas
/// totales de la región, en [0,1].
Map<String, double> _coveragePerRole(MaskSpec mask, ArrowBoard board) {
  final occupiedByRole = <String, Set<Position>>{};
  for (final arrow in board.arrows) {
    final role = arrow.paintRole;
    if (role == null) continue;
    occupiedByRole.putIfAbsent(role, () => <Position>{}).addAll(arrow.cells);
  }
  return {
    for (final region in mask.regions)
      region.role: region.cells
              .where(
                  (c) => occupiedByRole[region.role]?.contains(c) ?? false)
              .length /
          region.cells.length,
  };
}

/// Grid ANSI para curación: `█` coloreado por celda ocupada, `░` coloreado por
/// hueco de cobertura dentro de una región, espacio para el fondo `.`.
String _renderPreview(MaskSpec mask, ArrowBoard board) {
  final palette = mask.palette;

  final coveredHex = <Position, String>{};
  for (final arrow in board.arrows) {
    final hex = palette[arrow.paintRole];
    if (hex == null) continue;
    for (final cell in arrow.cells) {
      coveredHex[cell] = hex;
    }
  }
  final regionHex = <Position, String>{
    for (final region in mask.regions)
      for (final cell in region.cells) cell: region.hex,
  };

  final buf = StringBuffer();
  for (var row = 0; row < mask.rows; row++) {
    if (row > 0) buf.write('\n');
    for (var col = 0; col < mask.cols; col++) {
      final p = Position(row: row, col: col);
      final covered = coveredHex[p];
      if (covered != null) {
        buf.write(_ansiColored(covered, '█'));
        continue;
      }
      final gap = regionHex[p];
      if (gap != null) {
        buf.write(_ansiColored(gap, '░')); // hueco visible para el curador
        continue;
      }
      buf.write(' ');
    }
  }
  return buf.toString();
}

/// Envuelve [ch] en truecolor ANSI de primer plano: `#RRGGBB` →
/// `\x1b[38;2;R;G;Bm<ch>\x1b[0m`.
String _ansiColored(String hex, String ch) {
  final r = int.parse(hex.substring(1, 3), radix: 16);
  final g = int.parse(hex.substring(3, 5), radix: 16);
  final b = int.parse(hex.substring(5, 7), radix: 16);
  return '\x1b[38;2;$r;$g;${b}m$ch\x1b[0m';
}
