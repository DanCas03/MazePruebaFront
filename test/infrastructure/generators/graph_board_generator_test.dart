import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

/// Solucionador voraz (Kahn): retira repetidamente cualquier flecha cuyo
/// recorrido esté libre. Si el grafo de dependencias es un DAG, limpia el
/// tablero por completo.
bool greedySolves(ArrowBoard original) {
  final board = original.copy();
  var progressed = true;
  while (!board.isCleared && progressed) {
    progressed = false;
    for (final arrow in board.arrows) {
      if (board.canExit(arrow)) {
        board.removeArrow(arrow.id);
        progressed = true;
        break;
      }
    }
  }
  return board.isCleared;
}

void main() {
  final generator = GraphBoardGenerator();

  test('todos los tableros generados son resolubles (DAG) y no triviales', () {
    for (var level = 1; level <= 20; level++) {
      // Arrange
      final board = generator.generate(LevelId(level));

      // Assert
      expect(board.remaining, greaterThan(0),
          reason: 'El nivel $level no debería estar vacío');
      expect(greedySolves(board), isTrue,
          reason: 'El nivel $level debería ser resoluble');
    }
  });

  test('la generación es determinista por LevelId', () {
    // Arrange
    final a = generator.generate(const LevelId(7));
    final b = generator.generate(const LevelId(7));

    // Assert
    expect(a.remaining, equals(b.remaining));
    expect(a.width, equals(b.width));
    for (var i = 0; i < a.arrows.length; i++) {
      expect(a.arrows[i].tail, equals(b.arrows[i].tail));
      expect(a.arrows[i].direction, equals(b.arrows[i].direction));
      expect(a.arrows[i].length, equals(b.arrows[i].length));
    }
  });

  test('las flechas no se solapan entre sí', () {
    // Arrange
    final board = generator.generate(const LevelId(12));
    final occupied = <String>{};

    // Act / Assert
    for (final arrow in board.arrows) {
      for (final cell in arrow.cells) {
        final key = '${cell.x},${cell.y}';
        expect(occupied.contains(key), isFalse,
            reason: 'Celda $key ocupada por dos flechas');
        occupied.add(key);
      }
    }
  });
}
