import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_level_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/strike_count.dart';

// Board 4x4 con una sola flecha recta (0,0)->(0,1) mirando a la derecha:
// suficiente para satisfacer la invariante "al menos una flecha" de Level.
ArrowBoard _boardWithOneArrow() => ArrowBoard(
      arrows: [
        Arrow(
          id: const ArrowId('a1'),
          cells: [
            Position(row: 0, col: 0),
            Position(row: 0, col: 1),
          ],
          headDirection: Direction.right,
        ),
      ],
      space: RectSpace(4, 4),
    );

void main() {
  group('Level', () {
    test(
        'should_expose_id_board_and_timeLimitSec_when_constructed_with_valid_data',
        () {
      // Arrange
      final id = LevelId('1');
      final board = _boardWithOneArrow();
      // Act
      final level = Level(id: id, board: board, timeLimitSec: 60);
      // Assert
      expect(level.id, id);
      expect(level.board, board);
      expect(level.timeLimitSec, 60);
    });

    test('should_construct_with_null_timeLimitSec_when_no_limit_is_given', () {
      // Arrange
      final id = LevelId('1');
      final board = _boardWithOneArrow();
      // Act
      final level = Level(id: id, board: board);
      // Assert
      expect(level.timeLimitSec, isNull);
    });

    test('should_throw_InvalidLevelException_when_board_has_no_arrows', () {
      // Arrange
      final id = LevelId('1');
      final emptyBoard = ArrowBoard(arrows: const [], space: RectSpace(4, 4));
      // Act
      Level act() => Level(id: id, board: emptyBoard);
      // Assert
      expect(act, throwsA(isA<InvalidLevelException>()));
    });

    test('should_throw_InvalidLevelException_when_timeLimitSec_is_zero', () {
      // Arrange
      final id = LevelId('1');
      final board = _boardWithOneArrow();
      // Act
      Level act() => Level(id: id, board: board, timeLimitSec: 0);
      // Assert
      expect(act, throwsA(isA<InvalidLevelException>()));
    });

    test('should_throw_InvalidLevelException_when_timeLimitSec_is_negative',
        () {
      // Arrange
      final id = LevelId('1');
      final board = _boardWithOneArrow();
      // Act
      Level act() => Level(id: id, board: board, timeLimitSec: -5);
      // Assert
      expect(act, throwsA(isA<InvalidLevelException>()));
    });

    test('should_be_equal_when_id_board_and_timeLimitSec_all_match', () {
      // Arrange
      final levelA =
          Level(id: LevelId('1'), board: _boardWithOneArrow(), timeLimitSec: 30);
      final levelB =
          Level(id: LevelId('1'), board: _boardWithOneArrow(), timeLimitSec: 30);
      // Act
      final result = levelA == levelB;
      // Assert
      expect(result, isTrue);
    });

    test('should_not_be_equal_when_id_differs', () {
      // Arrange
      final board = _boardWithOneArrow();
      final levelA = Level(id: LevelId('1'), board: board, timeLimitSec: 30);
      final levelB = Level(id: LevelId('2'), board: board, timeLimitSec: 30);
      // Act
      final result = levelA == levelB;
      // Assert
      expect(result, isFalse);
    });

    test('should_not_be_equal_when_board_differs', () {
      // Arrange
      final id = LevelId('1');
      final otherBoard = ArrowBoard(
        arrows: [
          Arrow(
            id: const ArrowId('a2'),
            cells: [
              Position(row: 1, col: 0),
              Position(row: 1, col: 1),
            ],
            headDirection: Direction.right,
          ),
        ],
        space: RectSpace(4, 4),
      );
      final levelA =
          Level(id: id, board: _boardWithOneArrow(), timeLimitSec: 30);
      final levelB = Level(id: id, board: otherBoard, timeLimitSec: 30);
      // Act
      final result = levelA == levelB;
      // Assert
      expect(result, isFalse);
    });

    test('should_not_be_equal_when_timeLimitSec_differs', () {
      // Arrange
      final id = LevelId('1');
      final board = _boardWithOneArrow();
      final levelA = Level(id: id, board: board, timeLimitSec: 30);
      final levelB = Level(id: id, board: board, timeLimitSec: 60);
      // Act
      final result = levelA == levelB;
      // Assert
      expect(result, isFalse);
    });

    // front#83 — Presupuesto de errores por nivel (contador descendente).
    test('should_default_maxErrors_to_the_strike_budget_when_omitted', () {
      // Arrange
      final level = Level(id: LevelId('1'), board: _boardWithOneArrow());
      // Act & Assert: sin campo en el wire, cae al presupuesto por defecto.
      expect(level.maxErrors, StrikeCount.defaultMax);
    });

    test('should_carry_a_per_level_maxErrors_when_provided', () {
      // Arrange & Act
      final level =
          Level(id: LevelId('1'), board: _boardWithOneArrow(), maxErrors: 3);
      // Assert
      expect(level.maxErrors, 3);
    });

    test('should_throw_InvalidLevelException_when_maxErrors_is_zero', () {
      // Act
      Level act() =>
          Level(id: LevelId('1'), board: _boardWithOneArrow(), maxErrors: 0);
      // Assert
      expect(act, throwsA(isA<InvalidLevelException>()));
    });

    test('should_throw_InvalidLevelException_when_maxErrors_is_negative', () {
      // Act
      Level act() =>
          Level(id: LevelId('1'), board: _boardWithOneArrow(), maxErrors: -2);
      // Assert
      expect(act, throwsA(isA<InvalidLevelException>()));
    });

    test('should_not_be_equal_when_maxErrors_differs', () {
      // Arrange
      final board = _boardWithOneArrow();
      final levelA = Level(id: LevelId('1'), board: board, maxErrors: 3);
      final levelB = Level(id: LevelId('1'), board: board, maxErrors: 5);
      // Act & Assert
      expect(levelA == levelB, isFalse);
    });

    // front#67 — Instrucciones de pintado (ADR 0004): la paleta es un dato
    // opaco que solo portan los niveles temáticos.
    test('should_default_palette_to_null_when_omitted', () {
      // Arrange
      final id = LevelId('1');
      final board = _boardWithOneArrow();
      // Act
      final level = Level(id: id, board: board);
      // Assert
      expect(level.palette, isNull);
    });

    test('should_carry_opaque_palette_when_provided', () {
      // Arrange
      final id = LevelId('t-smiley');
      final board = _boardWithOneArrow();
      // Act
      final level = Level(
        id: id,
        board: board,
        palette: const {'cara': '#FBBF24', 'ojo': '#1E293B'},
      );
      // Assert
      expect(level.palette, {'cara': '#FBBF24', 'ojo': '#1E293B'});
    });

    test('should_be_equal_when_palettes_have_the_same_entries', () {
      // Arrange
      final board = _boardWithOneArrow();
      final levelA = Level(
          id: LevelId('t-smiley'),
          board: board,
          palette: const {'cara': '#FBBF24'});
      final levelB = Level(
          id: LevelId('t-smiley'),
          board: board,
          palette: const {'cara': '#FBBF24'});
      // Act
      final result = levelA == levelB;
      // Assert
      expect(result, isTrue);
    });

    test('should_not_be_equal_when_palette_differs', () {
      // Arrange
      final id = LevelId('t-smiley');
      final board = _boardWithOneArrow();
      final levelA =
          Level(id: id, board: board, palette: const {'cara': '#FBBF24'});
      final levelB =
          Level(id: id, board: board, palette: const {'cara': '#000000'});
      // Act
      final result = levelA == levelB;
      // Assert
      expect(result, isFalse);
    });

    // front#114 — Silueta opaca: rol→celdas de su región de máscara, solo pintura.
    test('stores silhouette when provided and defaults to null', () {
      // Arrange
      final withSilhouette = Level(
        id: LevelId('t-x'),
        board: ArrowBoard(
          arrows: [
            Arrow(
              id: ArrowId('a0'),
              headDirection: Direction.right,
              cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
              paintRole: 'heart',
            ),
          ],
          space: RectSpace(4, 4),
        ),
        palette: const {'heart': '#FF4D6D'},
        silhouette: {
          'heart': [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        },
      );
      final withoutSilhouette = Level(
        id: LevelId('t-y'),
        board: _boardWithOneArrow(),
        silhouette: null,
      );
      // Act & Assert
      expect(withSilhouette.silhouette!['heart'], hasLength(2));
      expect(withoutSilhouette.silhouette, isNull);
    });
  });
}
