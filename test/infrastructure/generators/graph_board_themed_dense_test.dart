import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

import '../../../tool/level_production/mask_spec.dart';
import '../../../tool/level_production/validation.dart';

// ---------------------------------------------------------------------------
// Guardianes de GraphBoardGenerator.generateThemedDense (#118) sobre las
// máscaras REALES de producción (`tool/level_production/masks/`): el modo
// denso existe para que los tableros temáticos se vean sólidos y artesanales,
// y estos tests hacen imposible la degeneración que mató el intento anterior
// (pilas de flechas rectas cortas y paralelas).
//
// Definiciones congeladas aquí (ver task-5 del plan):
//  - CODO: cambio de dirección entre celdas consecutivas del CUERPO. Una
//    flecha de 2 celdas nunca tiene codo (un solo segmento); una "L" de
//    cuerpo recto con salida perpendicular tampoco cuenta.
//  - RECTA: flecha con 0 codos (cuerpo colineal).
//  - TERNA ANTI-COLUMNAS: tres flechas rectas con la MISMA headDirection
//    cuyos cuerpos yacen en 3 líneas paralelas contiguas (filas r,r+1,r+2 si
//    los cuerpos son horizontales; columnas c,c+1,c+2 si verticales) y cuyas
//    proyecciones sobre el eje de la línea comparten al menos una posición.
//  - HUECOS AL BORDE: distancia BFS multi-source de cada celda LIBRE de una
//    región a la celda de borde más cercana de esa región (celda de borde =
//    adyacente a fuera-de-región o fuera de tablero; profundidad 0). Dos
//    umbrales, porque miden cosas distintas:
//      * media <= 1.5 (congelado por el plan), y
//      * profundidad MÁXIMA <= 2, es decir NINGUNA celda libre a profundidad
//        >= 3. La media sola NO ve el fallo que este guardián existe para
//        cazar: con pocas celdas libres, varios huecos de borde (profundidad
//        0) diluyen una bolsa interior profunda y la media pasa igual. Peor:
//        la media PREMIA dejar muchos huecos superficiales. El máximo es el
//        que expresa la regla real ("las celdas libres se pegan al borde,
//        nunca se sientan en mitad de la figura").
//  - DENSIDAD: se elige la mejor seed de 0..99 (determinista: primero
//    detalle al 100%, luego mayor cobertura, luego seed más baja) y sobre ese
//    tablero corren TODOS los guardianes de FORMA. La densidad, en cambio, se
//    exige sobre TODAS las seeds (mínimo, no máximo): afirmar solo que la
//    MEJOR seed llega a 0.90 es casi gratis y no restringe al generador.
//  - MEZCLA DE LONGITUDES: la regla de variedad del plan dice "longitudes 2-5
//    celdas mezcladas". El ratio de codos solo no la protege: un tablero de
//    puros dominós (flechas de 2) más unas pocas serpientes largas puede
//    superar el 40% de codos y aun así verse picado fino. Estos dos umbrales
//    codifican el criterio estético del maintainer ("troncho como el conejo",
//    `themed/themed-bunny.preview.txt`): techo de dominós y suelo de flechas
//    largas.
// ---------------------------------------------------------------------------

const _maskDir = 'tool/level_production/masks';

/// Regiones densas desde una máscara: las regiones pequeñas (detalle: ojos,
/// boca) van PRIMERO — sus carriles de salida se reservan con el tablero aún
/// vacío, igual que hace themed_producer.dart — y `arrowCount` se fija al
/// tamaño de la región (la pasada principal barre sin tope; el objetivo real
/// del modo denso es la densidad, no la cuenta de flechas).
List<ThemedRegionSpec> _denseRegions(MaskSpec mask) {
  final sorted = mask.regions.toList()
    ..sort((a, b) => a.cells.length.compareTo(b.cells.length));
  return [
    for (final r in sorted)
      ThemedRegionSpec(
        role: r.role,
        cells: r.cells,
        arrowCount: r.cells.length,
        maxPathLen: r.cells.length >= 100 ? 6 : 4,
      ),
  ];
}

/// Roles de detalle = todas las regiones salvo la mayor (en happy_face:
/// `features`; en heart no hay ninguna).
Set<String> _detailRoles(MaskSpec mask) {
  if (mask.regions.length < 2) return {};
  final sorted = mask.regions.toList()
    ..sort((a, b) => a.cells.length.compareTo(b.cells.length));
  return {for (final r in sorted.take(sorted.length - 1)) r.role};
}

Direction _stepDir(Position from, Position to) {
  if (to.row < from.row) return Direction.up;
  if (to.row > from.row) return Direction.down;
  if (to.col < from.col) return Direction.left;
  return Direction.right;
}

/// Codos de una flecha: cambios de dirección entre celdas consecutivas del
/// cuerpo (definición del plan; independiente de headDirection).
int _elbowCount(Arrow a) {
  var elbows = 0;
  for (var i = 2; i < a.cells.length; i++) {
    if (_stepDir(a.cells[i - 2], a.cells[i - 1]) !=
        _stepDir(a.cells[i - 1], a.cells[i])) {
      elbows++;
    }
  }
  return elbows;
}

/// Distancia BFS de cada celda de la región a su borde (borde = profundidad 0).
Map<Position, int> _borderDepth(Set<Position> cells) {
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

/// true si existe una terna anti-columnas (ver definición en la cabecera).
bool _hasParallelStraightTriple(ArrowBoard board) {
  for (final dir in Direction.values) {
    final straights = [
      for (final a in board.arrows)
        if (a.headDirection == dir && _elbowCount(a) == 0) a
    ];
    // línea del cuerpo: fila si el cuerpo es horizontal, columna si vertical.
    // (line, minProj, maxProj) por orientación del CUERPO.
    final horizontal = <int, List<(int, int)>>{};
    final vertical = <int, List<(int, int)>>{};
    for (final a in straights) {
      final rows = a.cells.map((c) => c.row);
      final cols = a.cells.map((c) => c.col);
      final sameRow = rows.toSet().length == 1;
      if (sameRow) {
        final min = cols.reduce((x, y) => x < y ? x : y);
        final max = cols.reduce((x, y) => x > y ? x : y);
        horizontal.putIfAbsent(rows.first, () => []).add((min, max));
      } else {
        final min = rows.reduce((x, y) => x < y ? x : y);
        final max = rows.reduce((x, y) => x > y ? x : y);
        vertical.putIfAbsent(cols.first, () => []).add((min, max));
      }
    }
    for (final byLine in [horizontal, vertical]) {
      for (final line in byLine.keys) {
        final l0 = byLine[line];
        final l1 = byLine[line + 1];
        final l2 = byLine[line + 2];
        if (l0 == null || l1 == null || l2 == null) continue;
        for (final a in l0) {
          for (final b in l1) {
            for (final c in l2) {
              final lo = [a.$1, b.$1, c.$1].reduce((x, y) => x > y ? x : y);
              final hi = [a.$2, b.$2, c.$2].reduce((x, y) => x < y ? x : y);
              if (lo <= hi) return true;
            }
          }
        }
      }
    }
  }
  return false;
}

/// Fixture por máscara: escaneo determinista de seeds 0..99 y mejor tablero.
class _DenseFixture {
  final MaskSpec mask;
  final List<ThemedRegionSpec> regions;
  final Set<Position> maskCells;
  final int bestSeed;
  final ArrowBoard board;
  final Set<Position> covered;

  /// Cobertura de CADA seed del barrido 0..99 (índice = seed). El barrido ya
  /// generaba los 100 tableros para elegir el mejor; guardarlas permite exigir
  /// el mínimo sin generar nada extra.
  final List<double> coverageBySeed;

  _DenseFixture._(this.mask, this.regions, this.maskCells, this.bestSeed,
      this.board, this.covered, this.coverageBySeed);

  factory _DenseFixture.scan(String maskName) {
    final mask =
        parseMaskSpec(File('$_maskDir/$maskName.mask').readAsStringSync());
    final regions = _denseRegions(mask);
    final maskCells = <Position>{
      for (final r in mask.regions) ...r.cells,
    };
    final detailRoles = _detailRoles(mask);
    final detailCells = <Position>{
      for (final r in mask.regions)
        if (detailRoles.contains(r.role)) ...r.cells,
    };

    final generator = GraphBoardGenerator();
    ArrowBoard? best;
    var bestSeed = -1;
    var bestKey = -1.0;
    final coverageBySeed = <double>[];
    for (var seed = 0; seed < 100; seed++) {
      final board = generator.generateThemedDense(
        cols: mask.cols,
        rows: mask.rows,
        regions: regions,
        seed: seed,
      );
      final covered = <Position>{
        for (final a in board.arrows) ...a.cells,
      };
      final coverage = covered.length / maskCells.length;
      coverageBySeed.add(coverage);
      final detailFull =
          detailCells.isEmpty || covered.containsAll(detailCells);
      // clave: primero detalle completo, luego cobertura; empate -> seed baja.
      final key = (detailFull ? 10.0 : 0.0) + coverage;
      if (key > bestKey) {
        bestKey = key;
        bestSeed = seed;
        best = board;
      }
    }
    final covered = <Position>{
      for (final a in best!.arrows) ...a.cells,
    };
    return _DenseFixture._(
        mask, regions, maskCells, bestSeed, best, covered, coverageBySeed);
  }

  double get coverage => covered.length / maskCells.length;

  /// Peor seed del barrido: la afirmación que de verdad restringe al generador.
  double get minCoverage => coverageBySeed.reduce((a, b) => a < b ? a : b);

  int get worstSeed => coverageBySeed.indexOf(minCoverage);
}

void main() {
  late _DenseFixture heart;
  late _DenseFixture happyFace;

  setUpAll(() {
    heart = _DenseFixture.scan('heart');
    happyFace = _DenseFixture.scan('happy_face');
  });

  group('GraphBoardGenerator.generateThemedDense — guardianes (#118)', () {
    test(
        'densidad: heart cubre >= 0.90 del total (608 celdas) con la mejor '
        'seed de 0..99', () {
      // Arrange: fixture escaneada en setUpAll.
      // Act
      final coverage = heart.coverage;
      // Assert
      expect(coverage, greaterThanOrEqualTo(0.90),
          reason: 'seed=${heart.bestSeed}: cobertura '
              '${heart.covered.length}/${heart.maskCells.length}');
    });

    test(
        'densidad: happy_face cubre >= 0.90 del total (392 celdas) y la '
        'región de detalle `features` al 100% (64/64)', () {
      // Arrange
      final features =
          happyFace.mask.regions.firstWhere((r) => r.role == 'features').cells;
      // Act
      final coverage = happyFace.coverage;
      final featuresCovered = features.where(happyFace.covered.contains).length;
      // Assert
      expect(coverage, greaterThanOrEqualTo(0.90),
          reason: 'seed=${happyFace.bestSeed}: cobertura '
              '${happyFace.covered.length}/${happyFace.maskCells.length}');
      expect(featuresCovered, features.length,
          reason: 'seed=${happyFace.bestSeed}: features '
              '$featuresCovered/${features.length}');
    });

    test(
        'densidad: TODAS las seeds 0..99 cubren >= 0.90 en ambas máscaras '
        '(mínimo, no solo la mejor)', () {
      // Arrange: los tests de arriba solo afirman la MEJOR seed, que es casi
      // gratis (es un máximo sobre 100 muestras). La afirmación que restringe
      // al generador es que NINGUNA seed baja de 0.90: así el producer de la
      // Task 7 puede escanear seeds sin miedo a un tablero agujereado.
      // Medido 2026-07-17: mínimo heart 0.9605 (seed 39), happy_face 0.9260
      // (seed 78) => 0.90 pasa con margen honesto en ambas.
      for (final fx in [heart, happyFace]) {
        // Act
        final min = fx.minCoverage;
        // Assert
        expect(min, greaterThanOrEqualTo(0.90),
            reason: '${fx.mask.name}: peor seed=${fx.worstSeed} con cobertura '
                '${min.toStringAsFixed(4)} sobre ${fx.maskCells.length} celdas');
      }
    });

    test('variedad: >= 40% de las flechas tienen >= 1 codo en ambas máscaras',
        () {
      for (final fx in [heart, happyFace]) {
        // Act
        final withElbow =
            fx.board.arrows.where((a) => _elbowCount(a) >= 1).length;
        final ratio = withElbow / fx.board.arrows.length;
        // Assert
        expect(ratio, greaterThanOrEqualTo(0.40),
            reason: '${fx.mask.name} seed=${fx.bestSeed}: '
                '$withElbow/${fx.board.arrows.length} flechas con codo');
      }
    });

    test(
        'anti-columnas: ninguna terna de flechas rectas paralelas adyacentes '
        'de la misma dirección con cuerpos solapados en proyección', () {
      for (final fx in [heart, happyFace]) {
        // Act + Assert
        expect(_hasParallelStraightTriple(fx.board), isFalse,
            reason: '${fx.mask.name} seed=${fx.bestSeed}: terna de rectas '
                'paralelas detectada (degeneración mecánica)');
      }
    });

    test(
        'huecos al borde: media de las celdas libres <= 1.5 Y ninguna celda '
        'libre a profundidad >= 3 (máximo <= 2)', () {
      for (final fx in [heart, happyFace]) {
        // Act
        var total = 0;
        var free = 0;
        var maxDepth = 0;
        Position? deepest;
        for (final region in fx.mask.regions) {
          final depth = _borderDepth(region.cells);
          for (final cell in region.cells) {
            if (fx.covered.contains(cell)) continue;
            total += depth[cell]!;
            free++;
            if (depth[cell]! > maxDepth) {
              maxDepth = depth[cell]!;
              deepest = cell;
            }
          }
        }
        final mean = free == 0 ? 0.0 : total / free;
        // Assert
        expect(mean, lessThanOrEqualTo(1.5),
            reason: '${fx.mask.name} seed=${fx.bestSeed}: media $mean '
                'sobre $free celdas libres');
        // El máximo es lo que la media no puede ver: una bolsa interior
        // profunda se esconde detrás de varios huecos de borde. Con las 6
        // celdas libres de heart, un singleton a profundidad 4 pasa la media.
        expect(maxDepth, lessThanOrEqualTo(2),
            reason: '${fx.mask.name} seed=${fx.bestSeed}: celda libre más '
                'profunda a $maxDepth (row=${deepest?.row}, col=${deepest?.col}) '
                'sobre $free libres; las celdas libres deben pegarse al borde');
      }
    });

    test(
        'variedad: mezcla de longitudes — dominós <= 55% y flechas de >= 4 '
        'celdas >= 20% en ambas máscaras', () {
      // Arrange: el plan pide "longitudes 2-5 celdas mezcladas", pero hasta
      // ahora solo el ratio de codos lo vigilaba, y el ratio de codos no
      // distingue un tablero troncho de uno picado fino. Estos dos umbrales
      // codifican el criterio estético del maintainer ("troncho como el
      // conejo"): un techo de dominós impide que el relleno degenere en
      // teselado de 2 celdas, y un suelo de flechas largas obliga a que haya
      // cuerpos con presencia. Medido 2026-07-17 sobre la mejor seed:
      //   heart      seed 98: 2:95 3:47 4:22 5:15 6:18 (197) =>
      //                       dominós 95/197 = 0.4822, len>=4 55/197 = 0.2792
      //   happy_face seed 41: 2:63 3:26 4:23 5:14 6:3  (129) =>
      //                       dominós 63/129 = 0.4884, len>=4 40/129 = 0.3101
      // Los umbrales (0.55 / 0.20) dejan margen honesto sobre esos valores sin
      // regalar espacio a la degeneración: el intento anterior murió por
      // exceso de flechas cortas.
      for (final fx in [heart, happyFace]) {
        // Act
        final total = fx.board.arrows.length;
        final dominoes =
            fx.board.arrows.where((a) => a.cells.length == 2).length;
        final long = fx.board.arrows.where((a) => a.cells.length >= 4).length;
        final histogram = <int, int>{};
        for (final a in fx.board.arrows) {
          histogram[a.cells.length] = (histogram[a.cells.length] ?? 0) + 1;
        }
        final sorted = Map.fromEntries(
            histogram.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
        // Assert
        expect(dominoes / total, lessThanOrEqualTo(0.55),
            reason: '${fx.mask.name} seed=${fx.bestSeed}: dominós '
                '$dominoes/$total; histograma $sorted');
        expect(long / total, greaterThanOrEqualTo(0.20),
            reason: '${fx.mask.name} seed=${fx.bestSeed}: flechas de >= 4 '
                'celdas $long/$total; histograma $sorted');
      }
    });

    test(
        'solvencia: validateCandidate no lanza (sin solape + vaciado en '
        'orden inverso)', () {
      for (final fx in [heart, happyFace]) {
        // Act + Assert
        expect(() => validateCandidate(fx.board), returnsNormally,
            reason: '${fx.mask.name} seed=${fx.bestSeed}');
      }
    });

    test('determinismo: misma seed => mismo tablero', () {
      final generator = GraphBoardGenerator();
      for (final fx in [heart, happyFace]) {
        // Act
        final again = generator.generateThemedDense(
          cols: fx.mask.cols,
          rows: fx.mask.rows,
          regions: fx.regions,
          seed: fx.bestSeed,
        );
        // Assert (ArrowBoard/Arrow son Equatable)
        expect(again, equals(fx.board),
            reason: '${fx.mask.name} seed=${fx.bestSeed}');
      }
    });

    test(
        'confinamiento y paintRole: cada cuerpo queda dentro de su región y '
        'lleva el rol de esa región', () {
      for (final fx in [heart, happyFace]) {
        final cellsByRole = {for (final r in fx.regions) r.role: r.cells};
        for (final arrow in fx.board.arrows) {
          final cells = cellsByRole[arrow.paintRole];
          expect(cells, isNotNull,
              reason: '${fx.mask.name}: paintRole ${arrow.paintRole}');
          for (final cell in arrow.cells) {
            expect(cells, contains(cell),
                reason: '${fx.mask.name}: ${arrow.id} fuera de su región');
          }
        }
      }
    });
  });
}
