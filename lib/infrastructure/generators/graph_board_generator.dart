import 'dart:math';
import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/space/rect_space.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

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
    final placed = <Arrow>[];
    // Estado interno incremental (#64): las celdas ocupadas por las flechas
    // YA aceptadas se acumulan aquí y se actualizan al aceptar cada flecha,
    // en lugar de reconstruirse (y de instanciar un ArrowBoard temporal) en
    // cada intento — eso hacía inviable un 50×50 denso (~10⁸ operaciones).
    final occupied = <Position>{};
    final maxAttempts = cols * rows * 30;
    var attempts = 0;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final candidate =
          _randomBentArrow(rng, cols, rows, placed.length, maxPathLen, occupied);
      if (candidate == null) continue;

      // Válido por construcción contra el estado local: _randomBentArrow
      // elige una cabeza con carril de salida libre de `occupied`, reserva
      // ese carril y crece el cuerpo evitando `occupied` — no hay overlap y
      // la salida queda libre en el momento de colocarla (invariante DAG).
      assert(candidate.cells.every((c) => !occupied.contains(c)),
          'candidate overlaps the incremental occupancy state');
      assert(
          RectSpace(cols, rows)
              .exitLane(candidate.head, candidate.headDirection)
              .every((p) => !occupied.contains(p)),
          'candidate exit lane is blocked at placement time');

      placed.add(candidate);
      occupied.addAll(candidate.cells);
    }

    if (placed.length < arrowCount) {
      _logger?.warn(
        'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
        'in ${cols}x$rows board after $attempts attempts (seed=$seed)',
        'GraphBoardGenerator',
      );
    }

    return ArrowBoard(arrows: placed, space: RectSpace(cols, rows));
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

    return ArrowBoard(arrows: placed, space: RectSpace(cols, rows));
  }

  /// Construye una flecha doblada: elige cabeza+dirección con carril de salida
  /// libre, reserva ese carril, y crece el cuerpo HACIA ATRÁS con una caminata
  /// aleatoria auto-evitante. Devuelve null si no logra un cuerpo de largo >= 2.
  ///
  /// [allowedBody] (#68) confina cabeza y cuerpo a esa región; el carril de
  /// salida NO se confina (sigue siendo de tablero completo). Con
  /// `allowedBody == null` el comportamiento — incluida la secuencia exacta de
  /// llamadas a [rng] — es idéntico al camino de campaña.
  Arrow? _randomBentArrow(Random rng, int cols, int rows, int index,
      int maxPathLen, Set<Position> occupied,
      {Set<Position>? allowedBody, String? paintRole}) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final head = _randomHeadWithClearLane(rng, cols, rows, dir, occupied,
        allowedBody: allowedBody);
    if (head == null) return null;

    // Reserva el carril de salida para que la flecha nunca bloquee su salida.
    final blocked = <Position>{...occupied, head, ..._lane(head, dir, cols, rows)};

    final body = <Position>[head]; // head..tail; se invierte al final
    final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
    var cursor = head;
    while (body.length < targetLen) {
      final options =
          _freeNeighbors(cursor, cols, rows, blocked, allowedBody: allowedBody);
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

  /// Celdas del carril recto desde la cabeza (exclusive) hasta el borde en [dir].
  List<Position> _lane(Position head, Direction dir, int cols, int rows) {
    return switch (dir) {
      Direction.right => List.generate(
          cols - 1 - head.col, (i) => Position(row: head.row, col: head.col + 1 + i)),
      Direction.left => List.generate(
          head.col, (i) => Position(row: head.row, col: head.col - 1 - i)),
      Direction.down => List.generate(
          rows - 1 - head.row, (i) => Position(row: head.row + 1 + i, col: head.col)),
      Direction.up => List.generate(
          head.row, (i) => Position(row: head.row - 1 - i, col: head.col)),
    };
  }

  /// Busca (hasta 20 intentos) una celda-cabeza libre cuyo carril recto al
  /// borde en [dir] esté libre de [occupied].
  ///
  /// Con [allowedBody] (#68) la cabeza se muestrea DESDE la región (eficiencia:
  /// muestrear el tablero completo desperdiciaría los 20 intentos en regiones
  /// pequeñas); el chequeo de carril sigue siendo contra [occupied] global.
  Position? _randomHeadWithClearLane(
      Random rng, int cols, int rows, Direction dir, Set<Position> occupied,
      {Set<Position>? allowedBody}) {
    if (allowedBody == null) {
      // Camino de campaña: byte a byte idéntico (misma secuencia de rng).
      for (var t = 0; t < 20; t++) {
        final head = Position(row: rng.nextInt(rows), col: rng.nextInt(cols));
        if (occupied.contains(head)) continue;
        final lane = _lane(head, dir, cols, rows);
        if (lane.every((p) => !occupied.contains(p))) return head;
      }
      return null;
    }

    final pool = allowedBody.toList(); // orden de iteración de Set estable
    if (pool.isEmpty) return null;
    for (var t = 0; t < 20; t++) {
      final head = pool[rng.nextInt(pool.length)];
      if (occupied.contains(head)) continue;
      final lane = _lane(head, dir, cols, rows);
      if (lane.every((p) => !occupied.contains(p))) return head;
    }
    return null;
  }

  /// Vecinos ortogonales en rango que no están bloqueados (ni fuera de
  /// [allowedBody], si se confina el cuerpo a una región — #68).
  List<Position> _freeNeighbors(
      Position p, int cols, int rows, Set<Position> blocked,
      {Set<Position>? allowedBody}) {
    final candidates = <Position>[
      if (p.row > 0) Position(row: p.row - 1, col: p.col),
      if (p.row < rows - 1) Position(row: p.row + 1, col: p.col),
      if (p.col > 0) Position(row: p.row, col: p.col - 1),
      if (p.col < cols - 1) Position(row: p.row, col: p.col + 1),
    ];
    return [
      for (final c in candidates)
        if (!blocked.contains(c) &&
            (allowedBody == null || allowedBody.contains(c)))
          c
    ];
  }
}
