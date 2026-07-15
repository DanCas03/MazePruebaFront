import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

/// Generador stub que implementa el puerto (nueva firma con maxPathLen y seed opcional):
/// verifica que el contrato es sustituible (LSP) y respeta la firma de generate.
class _StubLevelGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    final arrows = List.generate(
      arrowCount,
      (i) => straightArrow(
        id: ArrowId('a$i'),
        tail: Position(row: i, col: 0),
        direction: Direction.right,
        length: 2, // mínimo 2 según nueva regla
      ),
    );
    return ArrowBoard(arrows: arrows, space: RectSpace(cols, rows));
  }
}

void main() {
  group('ILevelGenerator contract', () {
    late ILevelGenerator sut;

    setUp(() {
      sut = _StubLevelGenerator();
    });

    test('generate returns a board with the requested dimensions', () {
      // Act
      final board = sut.generate(cols: 4, rows: 5, arrowCount: 2, maxPathLen: 3);
      // Assert
      expect(board.cols, 4);
      expect(board.rows, 5);
    });

    test('generate returns a board with the requested arrow count', () {
      // Act
      final board = sut.generate(cols: 4, rows: 4, arrowCount: 3, maxPathLen: 3);
      // Assert
      expect(board.arrows.length, 3);
    });

    test('generate accepts optional seed without breaking the contract', () {
      // Arrange / Act — seed pasado explícitamente
      final boardWithSeed =
          sut.generate(cols: 4, rows: 4, arrowCount: 2, maxPathLen: 3, seed: 42);
      // Assert — el puerto acepta seed; el stub lo ignora pero no falla
      expect(boardWithSeed.cols, 4);
      expect(boardWithSeed.arrows.length, 2);
    });

    test('generate without seed compiles and runs (seed is optional)', () {
      // Act — sin seed (null por defecto)
      final board = sut.generate(cols: 5, rows: 5, arrowCount: 3, maxPathLen: 3);
      // Assert
      expect(board.arrows.length, 3);
    });
  });
}
