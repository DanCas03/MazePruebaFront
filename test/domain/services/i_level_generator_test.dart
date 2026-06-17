import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';

/// Generador stub que implementa el puerto: verifica que el contrato es
/// sustituible (LSP) y respeta la firma de generate.
class _StubLevelGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({required int cols, required int rows, required int arrowCount}) {
    final arrows = List.generate(
      arrowCount,
      (i) => Arrow(
        id: ArrowId('a$i'),
        tail: Position(row: i, col: 0),
        direction: Direction.right,
        length: ArrowLength(1),
      ),
    );
    return ArrowBoard(arrows: arrows, cols: cols, rows: rows);
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
      final board = sut.generate(cols: 4, rows: 5, arrowCount: 2);
      // Assert
      expect(board.cols, 4);
      expect(board.rows, 5);
    });

    test('generate returns a board with the requested arrow count', () {
      // Act
      final board = sut.generate(cols: 4, rows: 4, arrowCount: 3);
      // Assert
      expect(board.arrows.length, 3);
    });
  });
}
