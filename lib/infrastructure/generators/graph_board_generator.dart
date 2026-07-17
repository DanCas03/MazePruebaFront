import 'dart:math';
import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/space/board_space.dart';
import '../../domain/game_core/space/masked_space.dart';
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

  /// Genera un tablero temático de COBERTURA TOTAL (#114): rellena la figura
  /// (unión de `region.cells`) con flechas RECTAS de largo >= 2, cubriendo
  /// ~100% de sus celdas. Usa solo `role` y `cells` de cada
  /// [ThemedRegionSpec] (ignora `arrowCount`/`maxPathLen` del spec).
  ///
  /// Algoritmo de "pelado" (peeling) que garantiza solubilidad DAG por
  /// construcción: se eligen flechas en orden de VACIADO — cada flecha pelada
  /// tiene su carril de salida libre de las celdas aún no peladas (las que
  /// pertenecerán a flechas que salen DESPUÉS). El orden de colocación es el
  /// inverso del pelado, así el tablero se vacía en orden inverso de
  /// colocación (mismo invariante que [generate]/[generateThemed]).
  ///
  /// El espacio es un [MaskedSpace]: las celdas fuera de la figura son
  /// frontera, así que una flecha "sale" en el borde de la silueta, no en el
  /// del rectángulo. Determinista (sin rng): candidatos ordenados por grado
  /// ascendente con desempate estable fila→columna.
  ArrowBoard generateThemedFull({
    required int cols,
    required int rows,
    required List<ThemedRegionSpec> regions,
    int maxPathLen = 6,
  }) {
    assert(maxPathLen >= 2, 'maxPathLen must be >= 2; got $maxPathLen');
    final activeCells = <Position>{for (final r in regions) ...r.cells};
    final space = MaskedSpace(cols, rows, activeCells: activeCells);
    // Cada celda pertenece a exactamente una región -> su rol de pintado.
    final cellRole = <Position, String>{
      for (final region in regions)
        for (final cell in region.cells) cell: region.role,
    };
    final remaining = Set<Position>.of(activeCells);
    final peelOrder = <Arrow>[]; // flechas en orden de VACIADO

    while (remaining.isNotEmpty) {
      // Grado = vecinos ortogonales en `remaining` con el MISMO rol. Pelar
      // primero las celdas de menor grado (puntas/esquinas) evita dejar
      // celdas huérfanas irreducibles en el interior de la figura.
      final degree = <Position, int>{
        for (final cell in remaining)
          cell: _sameRoleDegree(cell, space, remaining, cellRole),
      };
      final candidates = remaining.toList()
        ..sort((a, b) {
          final byDegree = degree[a]!.compareTo(degree[b]!);
          if (byDegree != 0) return byDegree;
          // Desempate estable (determinismo): fila, luego columna.
          final byRow = a.row.compareTo(b.row);
          return byRow != 0 ? byRow : a.col.compareTo(b.col);
        });

      var placedThisRound = false;
      for (final head in candidates) {
        final role = cellRole[head]!;
        List<Position>? bestBody; // [head, back1, back2, ...]
        Direction? bestDir;
        for (final dir in space.directions) {
          // Carril de salida en el ESPACIO ENMASCARADO: vacío significa que
          // la cabeza está en el borde de la figura y sale de inmediato.
          // Bloqueado si contiene celdas aún no peladas (esas pertenecen a
          // flechas que saldrán después de esta).
          final lane = space.exitLane(head, dir);
          if (lane.any(remaining.contains)) continue;

          // Cuerpo RECTO hacia atrás (opuesto a dir) por celdas del mismo
          // rol aún en `remaining`.
          final back = _oppositeOf(dir);
          final body = <Position>[head];
          var cursor = head;
          while (body.length < maxPathLen) {
            final prev = space.step(cursor, back);
            if (prev == null ||
                !remaining.contains(prev) ||
                body.contains(prev) ||
                cellRole[prev] != role) {
              break;
            }
            body.add(prev);
            cursor = prev;
          }
          if (body.length >= 2 &&
              (bestBody == null || body.length > bestBody.length)) {
            bestBody = body;
            bestDir = dir;
          }
        }
        if (bestBody != null) {
          remaining.removeAll(bestBody);
          peelOrder.add(Arrow(
            // Id provisional en orden de pelado; se re-indexa al invertir.
            id: ArrowId('arrow-${peelOrder.length}'),
            // cells va cola..cabeza (head LAST), como en generateThemed:
            // bestBody es [head, back1, ...] -> se invierte.
            cells: bestBody.reversed.toList(),
            headDirection: bestDir!,
            paintRole: role,
          ));
          placedThisRound = true;
          break;
        }
      }
      if (!placedThisRound) {
        // Resto irreducible con largo >= 2: esas celdas quedan sin cubrir
        // (degradación con gracia, misma filosofía que [generate]).
        _logger?.warn(
          'generateThemedFull: ${remaining.length} irreducible cells left '
          'uncovered in ${cols}x$rows mask',
          'GraphBoardGenerator',
        );
        break;
      }
    }

    // Orden de colocación = inverso del pelado (la última colocada sale
    // primero -> DAG). Re-indexa ids para que lean arrow-0..arrow-N en el
    // orden final de la lista, igual que generateThemed.
    final reversed = peelOrder.reversed.toList();
    final arrows = <Arrow>[
      for (var i = 0; i < reversed.length; i++)
        Arrow(
          id: ArrowId('arrow-$i'),
          cells: reversed[i].cells,
          headDirection: reversed[i].headDirection,
          paintRole: reversed[i].paintRole,
        ),
    ];
    return ArrowBoard(arrows: arrows, space: space);
  }

  /// Grado de [cell]: vecinos ortogonales en [remaining] con su mismo rol.
  int _sameRoleDegree(Position cell, BoardSpace space, Set<Position> remaining,
      Map<Position, String> cellRole) {
    final role = cellRole[cell];
    var degree = 0;
    for (final dir in space.directions) {
      final next = space.step(cell, dir);
      if (next != null && remaining.contains(next) && cellRole[next] == role) {
        degree++;
      }
    }
    return degree;
  }

  /// Inversión de dirección (no es aritmética dr/dc — el paso geométrico
  /// sigue delegado a [BoardSpace.step], ADR-0005 D2): el cuerpo recto crece
  /// hacia atrás, en sentido opuesto a la dirección de salida.
  Direction _oppositeOf(Direction dir) => switch (dir) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };

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
        for (final d in Direction.values)
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
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
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
