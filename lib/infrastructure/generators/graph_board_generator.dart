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
    int? seed,
  }) {
    final rng = Random(seed);
    final placed = <Arrow>[];
    final maxAttempts = cols * rows * 30; // escala con el tamaño del tablero
    var attempts = 0;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final candidate = _randomArrow(rng, cols, rows, placed.length);
      if (candidate == null) continue;

      final tempBoard =
          ArrowBoard(arrows: [...placed, candidate], cols: cols, rows: rows);
      // La candidata solo es válida si (1) no pisa el cuerpo de otra flecha y
      // (2) puede salir en el momento de colocarla. Sin (1) dos flechas
      // compartían celdas y se solapaban visualmente.
      if (!tempBoard.overlaps(candidate) && tempBoard.canExit(candidate.id)) {
        placed.add(candidate); // ids contiguos: arrow-0..arrow-(n-1)
      }
    }

    // Degradación con gracia: si no cupieron todas, devuelve las colocadas
    // y lo registra vía AOP logger (nunca lanza excepción).
    if (placed.length < arrowCount) {
      _logger?.warn(
        'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
        'in ${cols}x$rows board after $attempts attempts (seed=$seed)',
        'GraphBoardGenerator',
      );
    }

    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
  }

  Arrow? _randomArrow(Random rng, int cols, int rows, int index) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final horizontal = dir == Direction.left || dir == Direction.right;
    final axis = horizontal ? cols : rows;
    final maxLen = min(4, axis ~/ 2);
    if (maxLen < 2) return null; // eje demasiado corto para una flecha de >=2
    final length = 2 + rng.nextInt(maxLen - 1); // 2..maxLen

    final (rowMin, rowMax, colMin, colMax) = switch (dir) {
      Direction.right => (0, rows - 1, 0, cols - length),
      Direction.left => (0, rows - 1, length - 1, cols - 1),
      Direction.down => (0, rows - length, 0, cols - 1),
      Direction.up => (length - 1, rows - 1, 0, cols - 1),
    };
    if (rowMax < rowMin || colMax < colMin) return null;
    final row = rowMin + rng.nextInt(rowMax - rowMin + 1);
    final col = colMin + rng.nextInt(colMax - colMin + 1);

    return Arrow.straight(
      id: ArrowId('arrow-$index'),
      tail: Position(row: row, col: col),
      direction: dir,
      length: length,
    );
  }
}
