import 'dart:math';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/arrows/value_objects/arrow_length.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

// DAG algorithm: each arrow is placed only if it can exit at placement time.
// This guarantees solvability by construction — no backtracking needed.
class GraphBoardGenerator implements ILevelGenerator {
  final int? seed;
  GraphBoardGenerator({this.seed});

  @override
  ArrowBoard generate(
      {required int cols, required int rows, required int arrowCount}) {
    final rng = Random(seed);
    final placed = <Arrow>[];
    int attempts = 0;
    const maxAttempts = 500;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final candidate = _randomArrow(rng, cols, rows, placed.length);
      if (candidate == null) continue;

      final tempBoard =
          ArrowBoard(arrows: [...placed, candidate], cols: cols, rows: rows);
      // Only place if the new arrow can already exit (DAG invariant).
      if (tempBoard.canExit(candidate.id)) {
        placed.add(candidate);
      }
    }

    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
  }

  Arrow? _randomArrow(Random rng, int cols, int rows, int index) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final maxLen =
        dir == Direction.right || dir == Direction.left ? cols ~/ 2 : rows ~/ 2;
    if (maxLen < 1) return null;
    final length = rng.nextInt(maxLen) + 1;

    // Compute valid tail range for this direction and length
    final (rowMin, rowMax, colMin, colMax) = switch (dir) {
      Direction.right => (0, rows - 1, 0, cols - length),
      Direction.left => (0, rows - 1, length - 1, cols - 1),
      Direction.down => (0, rows - length, 0, cols - 1),
      Direction.up => (length - 1, rows - 1, 0, cols - 1),
    };

    if (rowMax < rowMin || colMax < colMin) return null;
    final row = rowMin + rng.nextInt(rowMax - rowMin + 1);
    final col = colMin + rng.nextInt(colMax - colMin + 1);

    return Arrow(
      id: ArrowId('arrow-$index'),
      tail: Position(row: row, col: col),
      direction: dir,
      length: ArrowLength(length),
    );
  }
}
