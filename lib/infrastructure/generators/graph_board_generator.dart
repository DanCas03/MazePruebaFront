import 'dart:math';
import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

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
    final maxAttempts = cols * rows * 30;
    var attempts = 0;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final occupied = <Position>{for (final a in placed) ...a.cells};
      final candidate =
          _randomBentArrow(rng, cols, rows, placed.length, maxPathLen, occupied);
      if (candidate == null) continue;

      final tempBoard =
          ArrowBoard(arrows: [...placed, candidate], cols: cols, rows: rows);
      if (!tempBoard.overlaps(candidate) && tempBoard.canExit(candidate.id)) {
        placed.add(candidate);
      }
    }

    if (placed.length < arrowCount) {
      _logger?.warn(
        'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
        'in ${cols}x$rows board after $attempts attempts (seed=$seed)',
        'GraphBoardGenerator',
      );
    }

    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
  }

  /// Construye una flecha doblada: elige cabeza+dirección con carril de salida
  /// libre, reserva ese carril, y crece el cuerpo HACIA ATRÁS con una caminata
  /// aleatoria auto-evitante. Devuelve null si no logra un cuerpo de largo >= 2.
  Arrow? _randomBentArrow(Random rng, int cols, int rows, int index,
      int maxPathLen, Set<Position> occupied) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final head = _randomHeadWithClearLane(rng, cols, rows, dir, occupied);
    if (head == null) return null;

    // Reserva el carril de salida para que la flecha nunca bloquee su salida.
    final blocked = <Position>{...occupied, head, ..._lane(head, dir, cols, rows)};

    final body = <Position>[head]; // head..tail; se invierte al final
    final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
    var cursor = head;
    while (body.length < targetLen) {
      final options = _freeNeighbors(cursor, cols, rows, blocked);
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
  Position? _randomHeadWithClearLane(
      Random rng, int cols, int rows, Direction dir, Set<Position> occupied) {
    for (var t = 0; t < 20; t++) {
      final head = Position(row: rng.nextInt(rows), col: rng.nextInt(cols));
      if (occupied.contains(head)) continue;
      final lane = _lane(head, dir, cols, rows);
      if (lane.every((p) => !occupied.contains(p))) return head;
    }
    return null;
  }

  /// Vecinos ortogonales en rango que no están bloqueados.
  List<Position> _freeNeighbors(
      Position p, int cols, int rows, Set<Position> blocked) {
    final candidates = <Position>[
      if (p.row > 0) Position(row: p.row - 1, col: p.col),
      if (p.row < rows - 1) Position(row: p.row + 1, col: p.col),
      if (p.col > 0) Position(row: p.row, col: p.col - 1),
      if (p.col < cols - 1) Position(row: p.row, col: p.col + 1),
    ];
    return [for (final c in candidates) if (!blocked.contains(c)) c];
  }
}
