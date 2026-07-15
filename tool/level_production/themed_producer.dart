// tool/level_production/themed_producer.dart
//
// Producción PURA de un nivel temático (front#68): mask → regiones →
// `generateThemed` por semilla → validar → medir cobertura → serializar.
// Sin IO ni argumentos de CLI — todo eso vive en `produce_themed.dart`
// (mismo reparto puro/CLI que candidate_producer.dart / produce.dart, front#65).
//
// La estrategia de cobertura: se piden deliberadamente MÁS flechas de las que
// caben (una por celda de la región) y el generador se auto-limita por
// intentos; luego se reintentan semillas hasta que TODAS las regiones alcanzan
// la cobertura objetivo, o se agotan las semillas y se usa la mejor vista.

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

  final int seedUsed;
  final int placedArrows;

  /// true si TODAS las regiones alcanzaron la cobertura objetivo con
  /// [seedUsed]; false si se agotaron las semillas y se usó la mejor vista.
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

/// Produce un nivel temático solvable a partir de [mask], reintentando las
/// [seeds] EN ORDEN hasta que todas las regiones alcancen [coverageTarget].
///
/// - Cada semilla se genera con `generateThemed` y se valida con
///   `validateCandidate`; una semilla inválida se salta sin abortar.
/// - Se rastrea la mejor semilla vista (la de MAYOR cobertura mínima entre
///   regiones); si ninguna alcanza el objetivo en todas las regiones, se usa
///   esa mejor (`allRegionsMetTarget == false`).
/// - El JSON se emite SIN `order` ni `timeLimitSec`: temático v1 no tiene
///   límite de tiempo, y como el encoder omite campos null, la AUSENCIA de
///   `timeLimitSec` es la anotación de "sin límite".
///
/// Con [seeds] vacío se intenta solo la semilla 0 (un intento determinista).
/// Lanza [StateError] si ninguna semilla produce un tablero válido.
ThemedResult produceThemed(
  MaskSpec mask, {
  double coverageTarget = 0.9,
  int maxPathLen = 4,
  Iterable<int> seeds = const [],
}) {
  final generator = GraphBoardGenerator();
  final levelId = 'themed-${mask.name}';

  final regionSpecs = <ThemedRegionSpec>[
    for (final region in mask.regions)
      ThemedRegionSpec(
        role: region.role,
        cells: region.cells,
        // Sobreoferta deliberada: una flecha "pedida" por celda. El generador
        // se auto-limita por intentos, así que esto maximiza el relleno de la
        // figura en vez de quedarse corto por un conteo conservador.
        arrowCount: region.cells.length,
        maxPathLen: maxPathLen,
      ),
  ];

  final seedList = seeds.isEmpty ? const <int>[0] : List<int>.of(seeds);

  ArrowBoard? bestBoard;
  Map<String, double>? bestCoverage;
  var bestSeed = 0;
  var bestMinCoverage = -1.0;
  var metTarget = false;

  for (final seed in seedList) {
    final board = generator.generateThemed(
      cols: mask.cols,
      rows: mask.rows,
      regions: regionSpecs,
      seed: seed,
    );
    try {
      validateCandidate(board);
    } on CandidateValidationException {
      continue; // semilla mala: se salta y se sigue probando
    }

    final coverage = _coveragePerRole(mask, board);
    if (coverage.values.every((c) => c >= coverageTarget)) {
      // Todas las regiones en objetivo: esta semilla gana y se corta la
      // búsqueda (determinista: siempre la PRIMERA semilla que lo logra).
      bestBoard = board;
      bestCoverage = coverage;
      bestSeed = seed;
      metTarget = true;
      break;
    }

    final minCoverage =
        coverage.values.reduce((a, b) => a < b ? a : b);
    if (minCoverage > bestMinCoverage) {
      bestMinCoverage = minCoverage;
      bestBoard = board;
      bestCoverage = coverage;
      bestSeed = seed;
    }
  }

  if (bestBoard == null || bestCoverage == null) {
    throw StateError(
      'no seed in ${seedList.first}..${seedList.last} produced a valid '
      'board for mask "${mask.name}"',
    );
  }

  return ThemedResult(
    levelId: levelId,
    json: const LevelJsonEncoder().encode(
      levelId: levelId,
      board: bestBoard,
      palette: mask.palette,
    ),
    coveragePerRole: bestCoverage,
    seedUsed: bestSeed,
    placedArrows: bestBoard.arrows.length,
    allRegionsMetTarget: metTarget,
    preview: _renderPreview(mask, bestBoard),
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
