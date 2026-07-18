import 'dart:math';
import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/space/board_space.dart';
import '../../domain/game_core/space/rect_space.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';
import 'band_layout.dart';

/// One themed region for [GraphBoardGenerator.generateThemed]: a set of cells
/// that a group of arrows must stay inside, all tagged with one paint role.
class ThemedRegionSpec {
  final String role; // -> Arrow.paintRole and palette key (ADR 0004)
  final Set<Position> cells; // the arrow bodies are confined to these cells
  final int arrowCount; // target arrows to place in this region
  final int maxPathLen;

  const ThemedRegionSpec({
    required this.role,
    required this.cells,
    required this.arrowCount,
    required this.maxPathLen,
  });
}

// DAG: cada flecha se coloca solo si YA puede salir en el momento de colocarla.
// Esto garantiza solubilidad por construcción. La generación es determinista
// cuando se pasa [seed] (mismo seed ⇒ mismo tablero ⇒ restart reproducible).
class GraphBoardGenerator implements ILevelGenerator {
  // AOP: logger opcional para registrar degradación con gracia sin acoplar
  // la lógica de negocio a un logger concreto (DIP). Constructor sin args
  // sigue siendo válido para main.dart y tests.
  final ILoggerService? _logger;

  GraphBoardGenerator({ILoggerService? logger}) : _logger = logger;

  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    assert(maxPathLen >= 2, 'maxPathLen must be >= 2; got $maxPathLen');
    final rng = Random(seed);
    final space = RectSpace(cols, rows);
    final placed = <Arrow>[];
    // Estado interno incremental (#64): las celdas ocupadas por las flechas
    // YA aceptadas se acumulan aquí y se actualizan al aceptar cada flecha,
    // en lugar de reconstruirse (y de instanciar un ArrowBoard temporal) en
    // cada intento — eso hacía inviable un 50×50 denso (~10⁸ operaciones).
    final occupied = <Position>{};

    // Colocación interior-primero por bandas concéntricas (spec 2026-07-15):
    // las flechas centrales se colocan con el tablero vacío (carriles largos
    // baratos) y el perímetro al final, cuando solo los carriles cortos son
    // viables — homogeneidad por construcción, mismo invariante DAG.
    final bands = concentricBands(cols: cols, rows: rows);
    final quotas =
        largestRemainderQuotas(arrowCount, [for (final b in bands) b.length]);

    var carry = 0; // cuota no colocada que rueda a la banda siguiente
    var totalAttempts = 0;
    for (var i = 0; i < bands.length; i++) {
      final pool = bands[i];
      final target = quotas[i] + carry;
      var bandPlaced = 0;
      var attempts = 0;
      final maxAttempts = pool.length * 30;
      while (bandPlaced < target && attempts < maxAttempts) {
        attempts++;
        final candidate = _bentArrowFromPool(
            rng, space, pool, placed.length, maxPathLen, occupied);
        if (candidate == null) continue;

        // Válido por construcción contra el estado local: _bentArrowFromPool
        // elige una cabeza con carril de salida libre de `occupied`, reserva
        // ese carril y crece el cuerpo evitando `occupied` — no hay overlap y
        // la salida queda libre en el momento de colocarla (invariante DAG).
        assert(candidate.cells.every((c) => !occupied.contains(c)),
            'candidate overlaps the incremental occupancy state');
        assert(
            space
                .exitLane(candidate.head, candidate.headDirection)
                .every((p) => !occupied.contains(p)),
            'candidate exit lane is blocked at placement time');

        placed.add(candidate);
        occupied.addAll(candidate.cells);
        bandPlaced++;
      }
      carry = target - bandPlaced;
      totalAttempts += attempts;
    }

    if (placed.length < arrowCount) {
      _logger?.warn(
        'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
            'in ${cols}x$rows board after $totalAttempts attempts (seed=$seed)',
        'GraphBoardGenerator',
      );
    }

    return ArrowBoard(arrows: placed, space: space);
  }

  /// Genera un tablero temático (#68): cada [ThemedRegionSpec] confina los
  /// CUERPOS de sus flechas a `region.cells` y las etiqueta con `region.role`
  /// como [Arrow.paintRole]. El carril de salida sigue siendo de tablero
  /// completo (puede cruzar regiones — mecánicamente válido e intencional) y
  /// `occupied` es GLOBAL entre regiones, así que se preserva el invariante
  /// DAG: el tablero entero se vacía en orden inverso de colocación.
  /// NO está en el puerto [ILevelGenerator]: es un extra de infraestructura
  /// que consume el pipeline de producción temática, no la campaña.
  ArrowBoard generateThemed({
    required int cols,
    required int rows,
    required List<ThemedRegionSpec> regions,
    int? seed,
  }) {
    final rng = Random(seed);
    final space = RectSpace(cols, rows);
    final placed = <Arrow>[];
    // GLOBAL entre regiones -> preserva el DAG global (misma disciplina de
    // ocupación + carril que [generate]).
    final occupied = <Position>{};
    var index = 0;

    for (final region in regions) {
      var regionPlaced = 0;
      var attempts = 0;
      final maxAttempts = region.cells.length * 30;
      while (regionPlaced < region.arrowCount && attempts < maxAttempts) {
        attempts++;
        final candidate = _randomBentArrow(
          rng,
          space,
          cols,
          rows,
          index,
          region.maxPathLen,
          occupied,
          allowedBody: region.cells,
          paintRole: region.role,
        );
        if (candidate == null) continue;

        placed.add(candidate);
        occupied.addAll(candidate.cells);
        index++;
        regionPlaced++;
      }
      if (regionPlaced < region.arrowCount) {
        _logger?.warn(
          'themed region "${region.role}": placed $regionPlaced/'
              '${region.arrowCount} arrows (graceful degradation)',
          'GraphBoardGenerator',
        );
      }
    }

    return ArrowBoard(arrows: placed, space: space);
  }

  /// Modo denso temático (#118): mismo invariante DAG que [generateThemed]
  /// (una flecha solo se coloca si su carril de salida está libre en ese
  /// momento; `occupied` GLOBAL entre regiones ⇒ el tablero se vacía en orden
  /// inverso de colocación, resoluble por construcción), con refuerzos para
  /// que la figura quede SÓLIDA y artesanal en vez de degenerar en pilas de
  /// rectas cortas paralelas:
  ///
  ///  1. **Interior-primero por coste de carril:** las cabezas se recorren
  ///     ordenadas por el coste de su escape MÁS BARATO, descendente (coste =
  ///     celdas enmascaradas que su carril debe cruzar; ∞ si el carril ya está
  ///     bloqueado al arrancar la región). Las celdas cuya única salida cruza
  ///     mucho tablero (centro de la región, canales a la sombra de una región
  ///     de detalle) se cubren cuando más carriles libres quedan; las de borde,
  ///     con escapes casi gratis, al final.
  ///  2. **Celda-primero + sesgo a codos:** como [_bentArrowFromPool], la
  ///     dirección se sortea entre las FACTIBLES de la celda (no a priori), y
  ///     el cuerpo prefiere doblar con probabilidad [bendBias].
  ///  3. **Anti-varado:** entre las direcciones factibles se prefiere el
  ///     cuerpo que NO deje celdas libres aisladas (una celda sin vecinos
  ///     libres jamás podrá cubrirse: cuerpo mínimo = 2).
  ///  4. **Anti-columnas:** un candidato RECTO que completaría una terna de
  ///     rectas paralelas adyacentes de la misma dirección se reintenta con
  ///     doblez forzado y, si no puede, se descarta.
  ///  5. **Pasadas de relleno:** tras la pasada principal se insiste con
  ///     flechas cortas (objetivo [gapFillMaxLen], mínimo 2), recorriendo las
  ///     celdas libres EXTREMO-primero (menos vecinos libres primero, para
  ///     tapizar pasillos desde sus puntas), hasta una pasada sin progreso.
  ///
  /// `region.arrowCount` es objetivo SOLO de la pasada principal; el objetivo
  /// real del modo es la densidad. Los carriles se evalúan sobre el
  /// [RectSpace] completo: al montarse en juego sobre un MaskedSpace los
  /// carriles son sub-conjuntos (terminan antes, en la frontera de la
  /// máscara), así que carril-libre en generación ⟹ carril-libre en juego.
  ///
  /// Las regiones se procesan en el orden dado: colocar PRIMERO las regiones
  /// de detalle (pequeñas) reserva sus carriles con el tablero aún vacío
  /// (misma convención que themed_producer.dart).
  ArrowBoard generateThemedDense({
    required int cols,
    required int rows,
    required List<ThemedRegionSpec> regions,
    int? seed,
    int gapFillMaxLen = 3,
    double bendBias = 0.7,
  }) {
    assert(
        gapFillMaxLen >= 2, 'gapFillMaxLen must be >= 2; got $gapFillMaxLen');
    final rng = Random(seed);
    final space = RectSpace(cols, rows);
    final placed = <Arrow>[];
    final occupied = <Position>{};
    // Celdas de CUALQUIER región: las únicas que pueden llegar a bloquear un
    // carril (el fondo fuera de la máscara nunca se ocupa).
    final maskCells = <Position>{
      for (final r in regions) ...r.cells,
    };
    // Rectas ya colocadas, indexadas para el veto anti-columnas:
    // headDirection -> línea del cuerpo -> intervalos proyectados.
    final straightRows = <Direction, Map<int, List<List<int>>>>{};
    final straightCols = <Direction, Map<int, List<List<int>>>>{};
    var index = 0;

    for (final region in regions) {
      final ordered =
          _laneCostOrder(rng, space, region.cells, maskCells, occupied);
      final staticRank = <Position, int>{
        for (var i = 0; i < ordered.length; i++) ordered[i]: i,
      };

      // Carriles aún libres de cada celda LIBRE de la región, mantenidos de
      // forma incremental: al colocar un cuerpo solo mueren los carriles que
      // lo cruzan (los rayos axiales desde cada celda del cuerpo).
      final clearLanes = <Position, Set<Direction>>{
        for (final c in ordered)
          if (!occupied.contains(c))
            c: {
              for (final d in space.directions)
                if (space.exitLane(c, d).every((p) => !occupied.contains(p))) d
            },
      };

      // Pasada principal DINÁMICA: siempre se coloca primero la celda libre
      // más amenazada (menos carriles libres restantes; empate → mayor coste
      // estático de carril, i.e. más interior). Así ninguna celda profunda
      // "muere" esperando su turno del barrido — el mecanismo que degeneraba
      // en bolsas interiores imposibles de rellenar.
      final deferred = <Position>{};
      var regionPlaced = 0;
      while (regionPlaced < region.arrowCount) {
        Position? pick;
        var pickLanes = 5;
        var pickRank = 1 << 30;
        for (final entry in clearLanes.entries) {
          final lanes = entry.value.length;
          if (lanes == 0 || deferred.contains(entry.key)) continue;
          final rank = staticRank[entry.key]!;
          if (lanes < pickLanes || (lanes == pickLanes && rank < pickRank)) {
            pick = entry.key;
            pickLanes = lanes;
            pickRank = rank;
          }
        }
        if (pick == null) break;

        var candidate = _denseArrowAt(
            rng,
            space,
            pick,
            region,
            region.maxPathLen,
            occupied,
            bendBias,
            index,
            straightRows,
            straightCols);
        // Rescate: si la celda amenazada no puede ser CABEZA (p. ej. su único
        // vecino libre cae sobre su propio carril), intenta cubrirla como
        // SEGUNDA celda del cuerpo de un vecino — es su última oportunidad:
        // los vecinos libres solo pueden disminuir.
        candidate ??= _rescueAsBody(rng, space, pick, region, region.maxPathLen,
            occupied, bendBias, index, straightRows, straightCols);
        if (candidate == null) {
          // Sin cuerpo viable AHORA: se aparta como cabeza (las pasadas de
          // relleno reintentan) pero sigue siendo cubrible como cuerpo ajeno.
          deferred.add(pick);
          continue;
        }
        _acceptDense(candidate, placed, occupied, straightRows, straightCols);
        for (final cell in candidate.cells) {
          clearLanes.remove(cell);
          deferred.remove(cell);
        }
        _killCrossedLanes(space, clearLanes, candidate.cells);
        index++;
        regionPlaced++;
      }

      // Pasadas de relleno: flechas cortas sobre cada celda libre, extremos
      // de pasillo primero, hasta que una pasada completa no coloque nada
      // (la ocupación solo crece ⇒ termina).
      var progress = true;
      while (progress) {
        progress = false;
        for (final head
            in _gapFillOrder(space, ordered, region.cells, occupied)) {
          final candidate = _denseArrowAt(
              rng,
              space,
              head,
              region,
              gapFillMaxLen,
              occupied,
              bendBias,
              index,
              straightRows,
              straightCols);
          if (candidate == null) continue;
          _acceptDense(candidate, placed, occupied, straightRows, straightCols);
          index++;
          progress = true;
        }
      }

      final freeLeft = region.cells.where((c) => !occupied.contains(c)).length;
      if (freeLeft > 0) {
        _logger?.warn(
          'dense themed region "${region.role}": $freeLeft/'
              '${region.cells.length} cells left uncovered (graceful degradation)',
          'GraphBoardGenerator',
        );
      }
    }

    return ArrowBoard(arrows: placed, space: space);
  }

  /// Mantenimiento incremental de [clearLanes]: una celda recién ocupada `b`
  /// bloquea el carril en dirección `opuesta(d)` de toda celda del rayo que
  /// sale de `b` en dirección `d` (la ocupación solo crece ⇒ no hay que
  /// re-escanear carriles completos).
  void _killCrossedLanes(BoardSpace space,
      Map<Position, Set<Direction>> clearLanes, List<Position> body) {
    const opposite = {
      Direction.up: Direction.down,
      Direction.down: Direction.up,
      Direction.left: Direction.right,
      Direction.right: Direction.left,
    };
    for (final b in body) {
      for (final d in space.directions) {
        var p = space.step(b, d);
        while (p != null) {
          clearLanes[p]?.remove(opposite[d]);
          p = space.step(p, d);
        }
      }
    }
  }

  /// Acepta un candidato denso: lo agrega, marca sus celdas y, si es RECTO,
  /// lo indexa para el veto anti-columnas de los candidatos posteriores.
  void _acceptDense(
      Arrow candidate,
      List<Arrow> placed,
      Set<Position> occupied,
      Map<Direction, Map<int, List<List<int>>>> straightRows,
      Map<Direction, Map<int, List<List<int>>>> straightCols) {
    placed.add(candidate);
    occupied.addAll(candidate.cells);
    final line = _straightLine(candidate.cells);
    if (line == null) return;
    final byLine = line.horizontal
        ? straightRows.putIfAbsent(candidate.headDirection, () => {})
        : straightCols.putIfAbsent(candidate.headDirection, () => {});
    byLine.putIfAbsent(line.line, () => []).add([line.min, line.max]);
  }

  /// Si el cuerpo es RECTO (colineal), devuelve su línea (fila si horizontal,
  /// columna si vertical) y el intervalo proyectado; null si tiene codos.
  ({bool horizontal, int line, int min, int max})? _straightLine(
      List<Position> cells) {
    final sameRow = cells.every((c) => c.row == cells.first.row);
    final sameCol = cells.every((c) => c.col == cells.first.col);
    if (sameRow) {
      var min = cells.first.col, max = cells.first.col;
      for (final c in cells) {
        if (c.col < min) min = c.col;
        if (c.col > max) max = c.col;
      }
      return (horizontal: true, line: cells.first.row, min: min, max: max);
    }
    if (sameCol) {
      var min = cells.first.row, max = cells.first.row;
      for (final c in cells) {
        if (c.row < min) min = c.row;
        if (c.row > max) max = c.row;
      }
      return (horizontal: false, line: cells.first.col, min: min, max: max);
    }
    return null;
  }

  /// true si un candidato recto en [line] con proyección [min..max] formaría,
  /// junto a dos rectas YA colocadas de la misma dirección en líneas paralelas
  /// contiguas, una terna con proyecciones de intersección común no vacía.
  bool _completesStraightTriple(Map<Direction, Map<int, List<List<int>>>> index,
      Direction dir, int line, int min, int max) {
    final byLine = index[dir];
    if (byLine == null) return false;
    // Ternas posibles con el candidato en línea L: {L-2,L-1}, {L-1,L+1},
    // {L+1,L+2}.
    for (final pair in [
      [line - 2, line - 1],
      [line - 1, line + 1],
      [line + 1, line + 2],
    ]) {
      final a = byLine[pair[0]];
      final b = byLine[pair[1]];
      if (a == null || b == null) continue;
      for (final ia in a) {
        for (final ib in b) {
          final lo = [min, ia[0], ib[0]].reduce((x, y) => x > y ? x : y);
          final hi = [max, ia[1], ib[1]].reduce((x, y) => x < y ? x : y);
          if (lo <= hi) return true;
        }
      }
    }
    return false;
  }

  /// Celdas de la región ordenadas por el coste de su escape más barato,
  /// DESCENDENTE, con desempate aleatorio determinista (clave [rng] por
  /// celda) para no imponer un patrón de barrido mecánico. Coste de un
  /// carril = nº de celdas de máscara que cruza; ∞ (representado como un
  /// coste enorme) si ya cruza una celda ocupada al arrancar la región.
  List<Position> _laneCostOrder(Random rng, BoardSpace space,
      Set<Position> cells, Set<Position> maskCells, Set<Position> occupied) {
    const dead = 1 << 20;
    final cost = <Position, int>{};
    for (final c in cells) {
      var best = dead;
      for (final d in space.directions) {
        var laneCost = 0;
        for (final p in space.exitLane(c, d)) {
          if (occupied.contains(p)) {
            laneCost = dead;
            break;
          }
          if (maskCells.contains(p)) laneCost++;
        }
        if (laneCost < best) best = laneCost;
      }
      cost[c] = best;
    }
    final order = cells.toList();
    final tie = <Position, double>{
      for (final c in order) c: rng.nextDouble(),
    };
    order.sort((a, b) {
      final byCost = cost[b]!.compareTo(cost[a]!);
      return byCost != 0 ? byCost : tie[a]!.compareTo(tie[b]!);
    });
    return order;
  }

  /// Orden de la pasada de relleno: solo celdas libres con >= 1 vecino libre
  /// (una celda aislada jamás alojará un cuerpo de 2), EXTREMO-primero (menos
  /// vecinos libres primero) para tapizar pasillos desde sus puntas; empata
  /// por el orden principal [ordered].
  List<Position> _gapFillOrder(BoardSpace space, List<Position> ordered,
      Set<Position> cells, Set<Position> occupied) {
    final rank = <Position, int>{
      for (var i = 0; i < ordered.length; i++) ordered[i]: i,
    };
    final freeDegree = <Position, int>{};
    for (final c in cells) {
      if (occupied.contains(c)) continue;
      var degree = 0;
      for (final d in space.directions) {
        final n = space.step(c, d);
        if (n != null && cells.contains(n) && !occupied.contains(n)) degree++;
      }
      if (degree > 0) freeDegree[c] = degree;
    }
    final result = freeDegree.keys.toList();
    result.sort((a, b) {
      final byDegree = freeDegree[a]!.compareTo(freeDegree[b]!);
      return byDegree != 0 ? byDegree : rank[a]!.compareTo(rank[b]!);
    });
    return result;
  }

  /// Rescate de una celda amenazada que no puede ser cabeza: intenta cubrir
  /// [target] como SEGUNDA celda del cuerpo de una flecha cuya cabeza es un
  /// vecino libre de [target] (con carril propio libre que NO pase por
  /// [target]). Mismo veto anti-columnas; sin reintento de doblez (último
  /// recurso). Devuelve null si ningún vecino puede.
  Arrow? _rescueAsBody(
      Random rng,
      BoardSpace space,
      Position target,
      ThemedRegionSpec region,
      int maxLen,
      Set<Position> occupied,
      double bendBias,
      int index,
      Map<Direction, Map<int, List<List<int>>>> straightRows,
      Map<Direction, Map<int, List<List<int>>>> straightCols) {
    final heads = <Position>[
      for (final d in space.directions)
        if (space.step(target, d) != null &&
            region.cells.contains(space.step(target, d)) &&
            !occupied.contains(space.step(target, d)))
          space.step(target, d)!
    ]..shuffle(rng);
    for (final head in heads) {
      final feasible = <Direction>[
        for (final d in space.directions)
          if (space
              .exitLane(head, d)
              .every((p) => p != target && !occupied.contains(p)))
            d
      ]..shuffle(rng);
      if (feasible.isEmpty) continue;
      final targetLen = maxLen <= 3 ? maxLen : 3 + rng.nextInt(maxLen - 2);
      for (final dir in feasible) {
        final lane = space.exitLane(head, dir);
        var body = _growBentBody(rng, space, head, targetLen,
            <Position>{...occupied, head, ...lane}, region.cells, bendBias,
            via: target);
        if (body.length < 2) continue;
        body = _trimToMinStranding(space, region.cells, occupied, body);
        final line = _straightLine(body);
        if (line != null &&
            _completesStraightTriple(
                line.horizontal ? straightRows : straightCols,
                dir,
                line.line,
                line.min,
                line.max)) {
          continue;
        }
        return Arrow(
          id: ArrowId('arrow-$index'),
          cells: body.reversed.toList(),
          headDirection: dir,
          paintRole: region.role,
        );
      }
    }
    return null;
  }

  /// Prefijo de [body] (cabeza intacta, cola recortada) más largo que no deja
  /// celdas libres aisladas; si todos dejan alguna, el de mínimo varado (y a
  /// igual varado, el más largo). Nunca recorta por debajo de 2.
  List<Position> _trimToMinStranding(BoardSpace space, Set<Position> cells,
      Set<Position> occupied, List<Position> body) {
    var best = body;
    var bestStranded = _strandedBy(space, cells, occupied, body);
    if (bestStranded == 0) return body;
    for (var len = body.length - 1; len >= 2; len--) {
      final shorter = body.sublist(0, len);
      final stranded = _strandedBy(space, cells, occupied, shorter);
      if (stranded == 0) return shorter;
      if (stranded < bestStranded) {
        bestStranded = stranded;
        best = shorter;
      }
    }
    return best;
  }

  /// Nº de celdas libres de la región que quedarían AISLADAS (sin ningún
  /// vecino libre) si se colocara [body]: varado permanente, porque el cuerpo
  /// mínimo de una flecha es 2.
  int _strandedBy(BoardSpace space, Set<Position> cells, Set<Position> occupied,
      List<Position> body) {
    final bodySet = body.toSet();
    final checked = <Position>{};
    var count = 0;
    for (final b in body) {
      for (final d in space.directions) {
        final n = space.step(b, d);
        if (n == null ||
            !cells.contains(n) ||
            occupied.contains(n) ||
            bodySet.contains(n) ||
            !checked.add(n)) {
          continue;
        }
        final isolated = space.directions.every((dd) {
          final m = space.step(n, dd);
          return m == null ||
              !cells.contains(m) ||
              occupied.contains(m) ||
              bodySet.contains(m);
        });
        if (isolated) count++;
      }
    }
    return count;
  }

  /// Intenta colocar una flecha densa con cabeza EXACTAMENTE en [head]:
  /// sortea las direcciones factibles (carril libre — celda-primero, como
  /// [_bentArrowFromPool]) y elige el cuerpo que no complete una terna de
  /// rectas (veto anti-columnas, con un reintento de doblez forzado) ni deje
  /// celdas varadas (anti-varado; si todos varan, el que menos). Devuelve
  /// null si la celda está ocupada, sin carril libre o sin espacio.
  Arrow? _denseArrowAt(
      Random rng,
      BoardSpace space,
      Position head,
      ThemedRegionSpec region,
      int maxLen,
      Set<Position> occupied,
      double bendBias,
      int index,
      Map<Direction, Map<int, List<List<int>>>> straightRows,
      Map<Direction, Map<int, List<List<int>>>> straightCols) {
    if (occupied.contains(head)) return null;
    final feasible = <Direction>[
      for (final d in space.directions)
        if (space.exitLane(head, d).every((p) => !occupied.contains(p))) d
    ]..shuffle(rng);
    if (feasible.isEmpty) return null;

    final targetLen = maxLen <= 3 ? maxLen : 3 + rng.nextInt(maxLen - 2);
    List<Position>? bestBody;
    Direction? bestDir;
    var bestStranded = -1;
    for (final dir in feasible) {
      final lane = space.exitLane(head, dir);
      var body = _growBentBody(rng, space, head, targetLen,
          <Position>{...occupied, head, ...lane}, region.cells, bendBias);
      if (body.length < 2) continue;

      // Anti-varado por recorte: si el cuerpo completo deja celdas aisladas,
      // prueba sus prefijos (recortando la cola) y quédate con el MÁS LARGO
      // que no vare ninguna; si ninguno lo logra, el de mínimo varado.
      body = _trimToMinStranding(space, region.cells, occupied, body);

      final line = _straightLine(body);
      if (line != null &&
          _completesStraightTriple(
              line.horizontal ? straightRows : straightCols,
              dir,
              line.line,
              line.min,
              line.max)) {
        // Veto anti-columnas: reintenta UNA vez con doblez forzado y objetivo
        // suficiente para poder doblar (>= 3).
        final retry = _growBentBody(
            rng,
            space,
            head,
            targetLen < 3 ? 3 : targetLen,
            <Position>{...occupied, head, ...lane},
            region.cells,
            1.0);
        if (retry.length < 2) continue;
        final retryLine = _straightLine(retry);
        if (retryLine != null &&
            _completesStraightTriple(
                retryLine.horizontal ? straightRows : straightCols,
                dir,
                retryLine.line,
                retryLine.min,
                retryLine.max)) {
          continue;
        }
        body = retry;
      }

      final stranded = _strandedBy(space, region.cells, occupied, body);
      if (stranded == 0) {
        bestBody = body;
        bestDir = dir;
        break;
      }
      if (bestStranded < 0 || stranded < bestStranded) {
        bestStranded = stranded;
        bestBody = body;
        bestDir = dir;
      }
    }
    if (bestBody == null || bestDir == null) return null;

    return Arrow(
      id: ArrowId('arrow-$index'),
      cells: bestBody.reversed.toList(), // cola (first) .. cabeza (last)
      headDirection: bestDir,
      paintRole: region.role,
    );
  }

  /// Caminata auto-evitante HACIA ATRÁS desde [head] con sesgo a codos: con
  /// probabilidad [bendBias] prefiere un vecino que cambie de dirección
  /// respecto al último paso, si existe (los guardianes de variedad y
  /// anti-columnas se apoyan en esto). Acepta cuerpos más cortos que
  /// [targetLen] si la caminata se seca.
  List<Position> _growBentBody(
      Random rng,
      BoardSpace space,
      Position head,
      int targetLen,
      Set<Position> blocked,
      Set<Position> allowedBody,
      double bendBias,
      {Position? via}) {
    final body = <Position>[head];
    var cursor = head;
    Direction? lastStep;
    if (via != null) {
      // Rescate: primer paso del cuerpo forzado a través de [via].
      body.add(via);
      blocked.add(via);
      lastStep = _stepDirection(head, via);
      cursor = via;
    }
    while (body.length < targetLen) {
      final options =
          _freeNeighbors(cursor, space, blocked, allowedBody: allowedBody);
      if (options.isEmpty) break;
      List<Position> pool = options;
      if (lastStep != null && rng.nextDouble() < bendBias) {
        final bending = <Position>[
          for (final o in options)
            if (_stepDirection(cursor, o) != lastStep) o
        ];
        if (bending.isNotEmpty) pool = bending;
      }
      final next = pool[rng.nextInt(pool.length)];
      lastStep = _stepDirection(cursor, next);
      body.add(next);
      blocked.add(next);
      cursor = next;
    }
    return body;
  }

  /// Dirección del paso entre dos celdas ortogonalmente adyacentes.
  Direction _stepDirection(Position from, Position to) {
    if (to.row < from.row) return Direction.up;
    if (to.row > from.row) return Direction.down;
    if (to.col < from.col) return Direction.left;
    return Direction.right;
  }

  /// Variante de campaña por bandas: muestrea la cabeza de [pool] y elige la
  /// dirección AL AZAR ENTRE LAS FACTIBLES (carril libre), en vez de imponerla
  /// a priori — una celda vale si cualquiera de sus carriles está libre. El
  /// cuerpo crece igual que en [_randomBentArrow] y puede salir del pool.
  Arrow? _bentArrowFromPool(Random rng, BoardSpace space, List<Position> pool,
      int index, int maxPathLen, Set<Position> occupied) {
    Position? head;
    Direction? dir;
    for (var t = 0; t < 20 && head == null; t++) {
      final cell = pool[rng.nextInt(pool.length)];
      if (occupied.contains(cell)) continue;
      final feasible = <Direction>[
        for (final d in space.directions)
          if (space.exitLane(cell, d).every((p) => !occupied.contains(p))) d
      ];
      if (feasible.isEmpty) continue;
      head = cell;
      dir = feasible[rng.nextInt(feasible.length)];
    }
    if (head == null || dir == null) return null;

    final blocked = <Position>{...occupied, head, ...space.exitLane(head, dir)};
    final body = <Position>[head]; // head..tail; se invierte al final
    final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
    var cursor = head;
    while (body.length < targetLen) {
      final options = _freeNeighbors(cursor, space, blocked);
      if (options.isEmpty) break; // acepta cuerpo más corto
      final next = options[rng.nextInt(options.length)];
      body.add(next);
      blocked.add(next);
      cursor = next;
    }
    if (body.length < 2) return null;

    return Arrow(
      id: ArrowId('arrow-$index'),
      cells: body.reversed.toList(),
      headDirection: dir,
    );
  }

  /// Construye una flecha doblada: elige cabeza+dirección con carril de salida
  /// libre, reserva ese carril, y crece el cuerpo HACIA ATRÁS con una caminata
  /// aleatoria auto-evitante. Devuelve null si no logra un cuerpo de largo >= 2.
  ///
  /// [allowedBody] (#68) confina cabeza y cuerpo a esa región; el carril de
  /// salida NO se confina (sigue siendo de tablero completo). Con
  /// `allowedBody == null` el comportamiento — incluida la secuencia exacta de
  /// llamadas a [rng] — es idéntico al camino de campaña.
  Arrow? _randomBentArrow(Random rng, BoardSpace space, int cols, int rows,
      int index, int maxPathLen, Set<Position> occupied,
      {Set<Position>? allowedBody, String? paintRole}) {
    final dirs = space.directions.toList();
    final dir = dirs[rng.nextInt(dirs.length)];
    final head = _randomHeadWithClearLane(rng, space, cols, rows, dir, occupied,
        allowedBody: allowedBody);
    if (head == null) return null;

    // Reserva el carril de salida para que la flecha nunca bloquee su salida.
    final blocked = <Position>{...occupied, head, ...space.exitLane(head, dir)};

    final body = <Position>[head]; // head..tail; se invierte al final
    final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
    var cursor = head;
    while (body.length < targetLen) {
      final options =
          _freeNeighbors(cursor, space, blocked, allowedBody: allowedBody);
      if (options.isEmpty) break; // acepta cuerpo más corto
      final next = options[rng.nextInt(options.length)];
      body.add(next);
      blocked.add(next);
      cursor = next;
    }
    if (body.length < 2) return null;

    return Arrow(
      id: ArrowId('arrow-$index'),
      cells: body.reversed.toList(), // cola (first) .. cabeza (last)
      headDirection: dir,
      paintRole: paintRole, // null en campaña -> sin cambios
    );
  }

  /// Busca (hasta 20 intentos) una celda-cabeza libre cuyo carril recto al
  /// borde en [dir] esté libre de [occupied].
  ///
  /// Con [allowedBody] (#68) la cabeza se muestrea DESDE la región (eficiencia:
  /// muestrear el tablero completo desperdiciaría los 20 intentos en regiones
  /// pequeñas); el chequeo de carril sigue siendo contra [occupied] global.
  Position? _randomHeadWithClearLane(Random rng, BoardSpace space, int cols,
      int rows, Direction dir, Set<Position> occupied,
      {Set<Position>? allowedBody}) {
    if (allowedBody == null) {
      // Camino de campaña: byte a byte idéntico (misma secuencia de rng). El
      // muestreo aleatorio de índice no es aritmética de espacio (ADR-0005)
      // — usa cols/rows como rango de rng.nextInt, no como chequeo geométrico.
      for (var t = 0; t < 20; t++) {
        final head = Position(row: rng.nextInt(rows), col: rng.nextInt(cols));
        if (occupied.contains(head)) continue;
        final lane = space.exitLane(head, dir);
        if (lane.every((p) => !occupied.contains(p))) return head;
      }
      return null;
    }

    final pool = allowedBody.toList(); // orden de iteración de Set estable
    if (pool.isEmpty) return null;
    for (var t = 0; t < 20; t++) {
      final head = pool[rng.nextInt(pool.length)];
      if (occupied.contains(head)) continue;
      final lane = space.exitLane(head, dir);
      if (lane.every((p) => !occupied.contains(p))) return head;
    }
    return null;
  }

  /// Vecinos ortogonales dentro del espacio que no están bloqueados (ni fuera
  /// de [allowedBody], si se confina el cuerpo a una región — #68). Itera
  /// [BoardSpace.directions] en vez de chequear bounds a mano: mismo orden
  /// (up, down, left, right — ver Direction) que la versión anterior, así que
  /// la secuencia de `rng.nextInt(options.length)` no cambia (ADR-0005).
  List<Position> _freeNeighbors(
      Position p, BoardSpace space, Set<Position> blocked,
      {Set<Position>? allowedBody}) {
    final result = <Position>[];
    for (final dir in space.directions) {
      final next = space.step(p, dir);
      if (next == null) continue;
      if (blocked.contains(next)) continue;
      if (allowedBody != null && !allowedBody.contains(next)) continue;
      result.add(next);
    }
    return result;
  }
}
