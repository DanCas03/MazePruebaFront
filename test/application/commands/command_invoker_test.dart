import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/commands/remove_arrow_command.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

void main() {
  late CommandInvoker sut;

  setUp(() => sut = CommandInvoker());

  ArrowBoard makeBoard() {
    final arrow = straightArrow(
      id: const ArrowId('a1'),
      tail: Position(row: 0, col: 0),
      direction: Direction.right,
      length: 2,
    );
    return ArrowBoard(arrows: [arrow], space: RectSpace(4, 4));
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

    test('undo delegates to the command, restoring onto the current board', () {
      // Arrange — start from a two-arrow board and remove a1.
      final a1 = straightArrow(
        id: const ArrowId('a1'),
        tail: Position(row: 0, col: 0),
        direction: Direction.right,
        length: 2,
      );
      final a2 = straightArrow(
        id: const ArrowId('a2'),
        tail: Position(row: 2, col: 0),
        direction: Direction.right,
        length: 2,
      );
      final board = ArrowBoard(arrows: [a1, a2], space: RectSpace(4, 4));
      final cmd = RemoveArrowCommand(const ArrowId('a1'));
      final afterRemove = sut.executeCommand(cmd, board);
      expect(afterRemove.arrows.map((a) => a.id), [const ArrowId('a2')]);
      // Simulate further mutation of the live board AFTER the command ran: a2 is
      // also removed. A correct invoker must undo a1 onto THIS current board, not
      // resurrect a stale pre-execute snapshot that still contains a2.
      final currentBoard = afterRemove.removeArrow(const ArrowId('a2'));
      expect(currentBoard.isCleared, isTrue);
      // Act — undo re-adds only a1 onto the current (empty) board.
      final restored = sut.undo(currentBoard);
      // Assert — exactly a1 is restored; a2 stays removed (no stale snapshot).
      expect(restored.arrows.map((a) => a.id), [const ArrowId('a1')]);
      expect(sut.canUndo, isFalse);
    });

    test('undo returns the same board when there is nothing to undo', () {
      // Arrange
      final board = makeBoard();
      // Act
      final result = sut.undo(board);
      // Assert
      expect(identical(result, board), isTrue);
      expect(sut.canUndo, isFalse);
    });

    test('clear vacía el historial: canUndo pasa a false', () {
      // Arrange — hay al menos un comando en el historial.
      final board = makeBoard();
      final cmd = RemoveArrowCommand(const ArrowId('a1'));
      sut.executeCommand(cmd, board);
      expect(sut.canUndo, isTrue);
      // Act
      sut.clear();
      // Assert
      expect(sut.canUndo, isFalse);
    });
  });
}
