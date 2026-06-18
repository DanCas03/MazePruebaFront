import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/commands/remove_arrow_command.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  late CommandInvoker sut;

  setUp(() => sut = CommandInvoker());

  ArrowBoard makeBoard() {
    final arrow = Arrow(
      id: const ArrowId('a1'),
      tail: Position(row: 0, col: 0),
      direction: Direction.right,
      length: ArrowLength(2),
    );
    return ArrowBoard(arrows: [arrow], cols: 4, rows: 4);
  }

  group('CommandInvoker', () {
    test('canUndo is false when history is empty', () {
      expect(sut.canUndo, isFalse);
    });

    test('executeCommand applies command and records it for undo', () {
      // Arrange
      final board = makeBoard();
      final cmd = RemoveArrowCommand(const ArrowId('a1'));
      // Act
      final result = sut.executeCommand(cmd, board);
      // Assert
      expect(result.isCleared, isTrue);
      expect(sut.canUndo, isTrue);
    });

    test('undo restores previous board state', () {
      // Arrange
      final board = makeBoard();
      final cmd = RemoveArrowCommand(const ArrowId('a1'));
      sut.executeCommand(cmd, board);
      // Act
      final restored = sut.undo(board);
      // Assert — board is restored (arrows count matches original)
      expect(restored.arrows.length, 1);
    });
  });
}
