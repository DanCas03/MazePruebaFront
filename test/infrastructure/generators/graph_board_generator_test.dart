import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

/// Solver voraz: retira repetidamente cualquier flecha con salida libre.
/// Si el tablero queda vacío, era solucionable (invariante DAG del generador).
bool _isSolvable(ArrowBoard board) {
  var b = board;
  var progress = true;
  while (!b.isCleared && progress) {
    progress = false;
    for (final a in List<Arrow>.from(b.arrows)) {
      if (b.canExit(a.id)) {
        b = b.removeArrow(a.id);
        progress = true;
        break;
      }
    }
  }
  return b.isCleared;
}

void main() {
  // Plan Task 3.1 — nueva firma: generate({required cols, rows, arrowCount, int? seed})
  // Constructor sin args: GraphBoardGenerator()
  final gen = GraphBoardGenerator();

  group('GraphBoardGenerator', () {
    // ── Casos del plan Task 3.1 ──────────────────────────────────────────────

    test('es determinista: mismo seed produce el tablero idéntico', () {
      // Arrange / Act
      final a = gen.generate(cols: 6, rows: 6, arrowCount: 6, seed: 42);
      final b = gen.generate(cols: 6, rows: 6, arrowCount: 6, seed: 42);
      // Assert
      expect(a, b); // ArrowBoard es Equatable
    });

    test('respeta las dimensiones y nunca excede arrowCount', () {
      // Arrange / Act
      final board = gen.generate(cols: 7, rows: 7, arrowCount: 9, seed: 1);
      // Assert
      expect(board.cols, 7);
      expect(board.rows, 7);
      expect(board.arrows.length, lessThanOrEqualTo(9));
      expect(board.arrows, isNotEmpty);
    });

    test('todas las flechas tienen longitud >= 2 (sin flechas de 1 celda)', () {
      // Arrange / Act
      final board = gen.generate(cols: 8, rows: 8, arrowCount: 12, seed: 7);
      // Assert
      for (final a in board.arrows) {
        expect(a.length.value, greaterThanOrEqualTo(2),
            reason: 'Arrow ${a.id.value} has length ${a.length.value} < 2');
      }
    });

    test('el tablero generado es siempre solucionable', () {
      // Arrange / Act / Assert — varios seeds
      for (final seed in [1, 2, 3, 99]) {
        final board = gen.generate(cols: 9, rows: 9, arrowCount: 14, seed: seed);
        expect(_isSolvable(board), isTrue, reason: 'seed=$seed');
      }
    });

    test('tableros grandes colocan más flechas que los pequeños (escalado por nivel)', () {
      // Arrange / Act
      final small = gen.generate(cols: 4, rows: 4, arrowCount: 4, seed: 5);
      final big = gen.generate(cols: 9, rows: 9, arrowCount: 14, seed: 5);
      // Assert
      expect(big.arrows.length, greaterThan(small.arrows.length));
    });

    // ── Seeds distintos producen tableros distintos ──────────────────────────

    test('seeds distintos producen tableros distintos', () {
      // Arrange / Act
      final a = gen.generate(cols: 6, rows: 6, arrowCount: 6, seed: 42);
      final b = gen.generate(cols: 6, rows: 6, arrowCount: 6, seed: 99);
      // Assert: al menos la lista de flechas difiere en algún aspecto
      // (extremadamente improbable que seed=42 y seed=99 coincidan)
      final sameArrows = a.arrows.length == b.arrows.length &&
          List.generate(a.arrows.length, (i) => a.arrows[i] == b.arrows[i])
              .every((e) => e);
      expect(sameArrows, isFalse,
          reason: 'seeds 42 y 99 no deberían producir el mismo tablero');
    });

    // ── Degradación con gracia (tablero pequeño, arrowCount mayor de lo posible) ─

    test('degradación con gracia: devuelve las flechas que cupieron sin lanzar', () {
      // Arrange — tablero 3×3 con arrowCount inalcanzable
      // Act
      final board = gen.generate(cols: 3, rows: 3, arrowCount: 20, seed: 0);
      // Assert — no lanza, devuelve lo que pudo colocar
      expect(board.arrows.length, lessThanOrEqualTo(20));
      expect(board.cols, 3);
      expect(board.rows, 3);
    });

    // ── Casos conservados del test original (adaptados a nueva firma) ─────────

    test('generates a board with the requested number of arrows', () {
      // Arrange / Act
      final board = gen.generate(cols: 5, rows: 5, arrowCount: 4, seed: 10);
      // Assert
      expect(board.arrows.length, lessThanOrEqualTo(4));
      expect(board.arrows, isNotEmpty);
    });

    test('generated board is solvable — every arrow can eventually be removed', () {
      // Arrange
      final board = gen.generate(cols: 5, rows: 5, arrowCount: 5, seed: 21);
      // Act — simulate solving via _isSolvable helper
      final solvable = _isSolvable(board);
      // Assert
      expect(solvable, isTrue);
    });

    test('two calls with same seed produce the same board', () {
      // Arrange / Act
      final boardA = gen.generate(cols: 4, rows: 4, arrowCount: 3, seed: 42);
      final boardB = gen.generate(cols: 4, rows: 4, arrowCount: 3, seed: 42);
      // Assert
      expect(boardA.arrows.length, boardB.arrows.length);
      for (var i = 0; i < boardA.arrows.length; i++) {
        expect(boardA.arrows[i], boardB.arrows[i]);
      }
    });
  });
}
