// tool/level_production/themed_producer.dart
//
// Producción PURA de un nivel temático (front#68, denso desde #118):
// mask → regiones → generar por semilla → validar → medir → serializar.
// Sin IO ni argumentos de CLI — todo eso vive en `produce_themed.dart`
// (mismo reparto puro/CLI que candidate_producer.dart / produce.dart, front#65).
//
// Modo DENSO (default, #118): `generateThemedDense` rellena la máscara al ~99%
// y la semilla se elige con el MISMO criterio lexicográfico que los guardianes
// de `test/infrastructure/generators/graph_board_themed_dense_test.dart`
// (detalle lleno → profundidad de hueco → cobertura); ver [selectDenseSeed].
// Elegir por cobertura sola NO es Pareto-óptimo: en heart la seed de mayor
// cobertura dejaba dos celdas libres a profundidad 3-4 EN MITAD de la figura.
//
// Modo legacy (`dense: false`): `generateThemed` con la estrategia original —
// se piden deliberadamente MÁS flechas de las que caben (una por celda) y se
// reintentan semillas hasta que TODAS las regiones alcanzan la cobertura
// objetivo, o se agotan las semillas y se usa la mejor vista.
//
// En ambos modos el JSON emite `silhouette` (#118): el fill COMPLETO de las
// regiones de la máscara (rol → celdas), NO la unión de las flechas — es la
// forma jugable del nivel (MaskedSpace), independiente de la cobertura.

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

/// Métricas de una semilla del barrido denso (#118): exactamente lo que el
/// criterio de selección necesita para decidir. Mismas definiciones que los
/// guardianes de `graph_board_themed_dense_test.dart` (congeladas allí):
/// [coverage] = celdas cubiertas / celdas de la máscara (unión de regiones);
/// [maxHoleDepth] = profundidad BFS máxima de una celda LIBRE al borde de su
/// región; [detailFull] = las regiones de detalle (todas menos la mayor)
/// cubiertas al 100%.
class DenseSeedMetrics {
  final int seed;
  final double coverage;
  final int maxHoleDepth;
  final bool detailFull;

  const DenseSeedMetrics({
    required this.seed,
    required this.coverage,
    required this.maxHoleDepth,
    required this.detailFull,
  });

  /// Admisible = criterios 1 y 2 del barrido (detalle lleno, sin bolsillos
  /// interiores). La cobertura NO entra aquí: solo desempata entre admisibles.
  bool get qualifies => detailFull && maxHoleDepth <= 2;
}

/// Selección lexicográfica de la semilla densa (#118) — el MISMO criterio que
/// los guardianes, en orden de prioridad ESTRICTA:
///
/// 1. detalle al 100% (la identidad de la figura: ojos/boca de happy_face),
/// 2. profundidad máxima de hueco <= 2 (sin celdas libres en mitad de la
///    figura),
/// 3. y solo entonces mayor cobertura entre las supervivientes.
///
/// NO elegir por cobertura sola: no es Pareto-óptimo (heart seed 98 gana UNA
/// celda de 608 sobre la seed 67 y a cambio deja una bolsa interior a
/// profundidad 4; happy_face seed 53 supera en cobertura a la 41 dejando un
/// ojo mordido). [metrics] debe venir en orden ascendente de seed: el `>`
/// estricto conserva la primera vista, así los empates los gana la seed más
/// baja. Devuelve `null` si ninguna califica (el caller decide el rojo
/// ruidoso; nunca degradarse en silencio a "la de más cobertura").
DenseSeedMetrics? selectDenseSeed(Iterable<DenseSeedMetrics> metrics) {
  DenseSeedMetrics? best;
  for (final m in metrics) {
    if (!m.qualifies) continue;
    if (best == null || m.coverage > best.coverage) best = m;
  }
  return best;
}

/// Regiones de [mask] ordenadas con las de detalle PRIMERO (las más
/// pequeñas): las regiones de detalle (ojos/boca en happy_face) reservan su
/// carril de salida con el tablero aún vacío; si la región exterior se
/// llenara primero ninguna flecha interior encontraría carril libre. MISMO
/// orden que usan el producer y los guardianes de
/// `graph_board_themed_dense_test.dart`.
List<MaskRegion> orderRegionsDetailFirst(MaskSpec mask) => mask.regions
    .toList()
  ..sort((a, b) => a.cells.length.compareTo(b.cells.length));

/// Specs de región para el modo denso (#118), en orden detalle-primero:
/// `arrowCount` = |celdas| de la región (la pasada principal barre sin tope
/// real; el objetivo es la densidad, no la cuenta de flechas) y `maxPathLen`
/// 6 para regiones >= 100 celdas, 4 para el resto. Política congelada,
/// compartida por el producer y los guardianes.
List<ThemedRegionSpec> denseRegionSpecs(MaskSpec mask) => [
      for (final region in orderRegionsDetailFirst(mask))
        ThemedRegionSpec(
          role: region.role,
          cells: region.cells,
          arrowCount: region.cells.length,
          maxPathLen: region.cells.length >= 100 ? 6 : 4,
        ),
    ];

/// Celdas de las regiones "de detalle" de [mask]: todas salvo la mayor
/// (identidad de la figura — ojos/boca en happy_face); vacío si la máscara
/// tiene menos de 2 regiones (en heart no hay detalle). MISMA definición que
/// usa [selectDenseSeed] vía `DenseSeedMetrics.detailFull` y los guardianes.
Set<Position> detailCellsOf(MaskSpec mask) {
  final ordered = orderRegionsDetailFirst(mask);
  if (ordered.length < 2) return const {};
  return {
    for (final region in ordered.take(ordered.length - 1)) ...region.cells,
  };
}

/// Produce un nivel temático solvable a partir de [mask].
///
/// Con [dense] (default, #118) usa `generateThemedDense`: barre TODAS las
/// [seeds] EN ORDEN, mide cada tablero (cobertura, profundidad de huecos,
/// detalle) y elige con [selectDenseSeed] — el criterio congelado de los
/// guardianes. [maxPathLen] NO aplica en denso: la política de longitudes es
/// la de los guardianes (6 para regiones >= 100 celdas, 4 para el resto),
/// congelada para que el producer aterrice en las MISMAS seeds que ellos.
/// Lanza [StateError] si ninguna semilla es admisible.
///
/// Con `dense: false` (legacy) usa `generateThemed` reintentando las [seeds]
/// EN ORDEN hasta que todas las regiones alcancen [coverageTarget]:
///
/// - Cada semilla se genera con `generateThemed` y se valida con
///   `validateCandidate`; una semilla inválida se salta sin abortar.
/// - Se rastrea la mejor semilla vista (la de MAYOR cobertura mínima entre
///   regiones); si ninguna alcanza el objetivo en todas las regiones, se usa
///   esa mejor (`allRegionsMetTarget == false`).
///
/// En ambos modos el JSON se emite SIN `order` ni `timeLimitSec` (temático v1
/// no tiene límite de tiempo; la AUSENCIA de `timeLimitSec` es la anotación)
/// y CON `silhouette` = fill completo de las regiones de la máscara.
///
/// Con [seeds] vacío se intenta solo la semilla 0 (un intento determinista).
/// Lanza [StateError] si ninguna semilla produce un tablero válido.
ThemedResult produceThemed(
  MaskSpec mask, {
  double coverageTarget = 0.9,
  int maxPathLen = 4,
  Iterable<int> seeds = const [],
  bool dense = true,
}) {
  final seedList = seeds.isEmpty ? const <int>[0] : List<int>.of(seeds);
  if (dense) {
    return _produceDense(mask, coverageTarget, seedList);
  }
  return _produceLegacy(mask, coverageTarget, maxPathLen, seedList);
}

/// Modo denso (#118): barrido completo de seeds + selección de guardianes.
ThemedResult _produceDense(
    MaskSpec mask, double coverageTarget, List<int> seedList) {
  final generator = GraphBoardGenerator();
  final levelId = 'themed-${mask.name}';

  // Orden detalle-primero + política de región compartida con los guardianes
  // (ver `orderRegionsDetailFirst`/`denseRegionSpecs`/`detailCellsOf`).
  final regionSpecs = denseRegionSpecs(mask);

  final maskCells = <Position>{
    for (final region in mask.regions) ...region.cells,
  };
  final detailCells = detailCellsOf(mask);
  // La profundidad al borde depende SOLO de la máscara (no del tablero): se
  // calcula una vez y se reutiliza en todas las seeds.
  final depthByRegion = [
    for (final region in mask.regions) borderDepth(region.cells),
  ];

  final metricsBySeed = <DenseSeedMetrics>[];
  final boardBySeed = <int, ArrowBoard>{};
  for (final seed in seedList) {
    final board = generator.generateThemedDense(
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

    final covered = <Position>{
      for (final arrow in board.arrows) ...arrow.cells,
    };
    var maxDepth = 0;
    for (var i = 0; i < mask.regions.length; i++) {
      for (final cell in mask.regions[i].cells) {
        if (covered.contains(cell)) continue;
        final depth = depthByRegion[i][cell]!;
        if (depth > maxDepth) maxDepth = depth;
      }
    }
    metricsBySeed.add(DenseSeedMetrics(
      seed: seed,
      coverage: covered.length / maskCells.length,
      maxHoleDepth: maxDepth,
      detailFull: detailCells.isEmpty || covered.containsAll(detailCells),
    ));
    boardBySeed[seed] = board;
  }

  final chosen = selectDenseSeed(metricsBySeed);
  if (chosen == null) {
    // Rojo ruidoso, nunca una elección silenciosa (mismo contrato que el
    // fixture de los guardianes): degradarse a "la de más cobertura" es
    // exactamente el fallo que el criterio existe para impedir.
    final detailFullCount = metricsBySeed.where((m) => m.detailFull).length;
    final depthOkCount =
        metricsBySeed.where((m) => m.maxHoleDepth <= 2).length;
    throw StateError(
      '${mask.name}: NINGUNA seed de ${seedList.first}..${seedList.last} '
      'cumple el criterio de selección (detalle al 100% Y profundidad máxima '
      '<= 2). Con detalle completo: $detailFullCount/${metricsBySeed.length}; '
      'con profundidad <= 2: $depthOkCount/${metricsBySeed.length}. '
      'Amplía el rango de seeds o retoca la máscara.',
    );
  }

  final board = boardBySeed[chosen.seed]!;
  final coveragePerRole = _coveragePerRole(mask, board);
  return ThemedResult(
    levelId: levelId,
    json: const LevelJsonEncoder().encode(
      levelId: levelId,
      board: board,
      palette: mask.palette,
      silhouette: _silhouetteOf(mask),
    ),
    coveragePerRole: coveragePerRole,
    seedUsed: chosen.seed,
    placedArrows: board.arrows.length,
    allRegionsMetTarget:
        coveragePerRole.values.every((c) => c >= coverageTarget),
    preview: _renderPreview(mask, board),
  );
}

/// Modo legacy (front#68): `generateThemed` + primera seed que alcanza el
/// objetivo en todas las regiones (o la mejor vista).
ThemedResult _produceLegacy(
    MaskSpec mask, double coverageTarget, int maxPathLen, List<int> seedList) {
  final generator = GraphBoardGenerator();
  final levelId = 'themed-${mask.name}';

  // Orden detalle-primero: las regiones pequeñas (interiores: ojos, boca) se
  // colocan antes que las grandes (cara, pelaje). El generateThemed exige que
  // cada flecha tenga su lane de salida al borde libre en el momento de
  // colocarla; si la región exterior se llenara primero, ninguna flecha
  // interior encontraría lane libre y esa región quedaría en 0%. Colocando los
  // detalles sobre el tablero (aún) vacío, todas las regiones reciben flechas.
  final orderedRegions = mask.regions.toList()
    ..sort((a, b) => a.cells.length.compareTo(b.cells.length));

  final regionSpecs = <ThemedRegionSpec>[
    for (final region in orderedRegions)
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
      silhouette: _silhouetteOf(mask),
    ),
    coveragePerRole: bestCoverage,
    seedUsed: bestSeed,
    placedArrows: bestBoard.arrows.length,
    allRegionsMetTarget: metTarget,
    preview: _renderPreview(mask, bestBoard),
  );
}

/// Silueta del fixture (#118): el fill COMPLETO de cada región de la máscara
/// (rol → celdas), NO la unión de las celdas de las flechas — la forma jugable
/// (MaskedSpace) es la figura entera, cubierta o no.
Map<String, Set<Position>> _silhouetteOf(MaskSpec mask) => {
      for (final region in mask.regions) region.role: region.cells,
    };

/// Distancia BFS multi-source de cada celda de la región a su borde (celda de
/// borde = adyacente a fuera-de-región o fuera de tablero; profundidad 0).
/// Fuente única (#118 fix): el producer y los guardianes de
/// `test/infrastructure/generators/graph_board_themed_dense_test.dart` miden
/// con esta MISMA regla — el guardián importa este símbolo en vez de
/// re-declararlo.
Map<Position, int> borderDepth(Set<Position> cells) {
  final depth = <Position, int>{};
  final queue = <Position>[];
  for (final c in cells) {
    final neighbors = [
      Position(row: c.row + 1, col: c.col),
      Position(row: c.row, col: c.col + 1),
      if (c.row > 0) Position(row: c.row - 1, col: c.col),
      if (c.col > 0) Position(row: c.row, col: c.col - 1),
    ];
    final isBorder =
        c.row == 0 || c.col == 0 || neighbors.any((n) => !cells.contains(n));
    if (isBorder) {
      depth[c] = 0;
      queue.add(c);
    }
  }
  var i = 0;
  while (i < queue.length) {
    final c = queue[i++];
    final neighbors = [
      Position(row: c.row + 1, col: c.col),
      Position(row: c.row, col: c.col + 1),
      if (c.row > 0) Position(row: c.row - 1, col: c.col),
      if (c.col > 0) Position(row: c.row, col: c.col - 1),
    ];
    for (final n in neighbors) {
      if (!cells.contains(n) || depth.containsKey(n)) continue;
      depth[n] = depth[c]! + 1;
      queue.add(n);
    }
  }
  return depth;
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
