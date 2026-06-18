import '../../domain/arrows/entities/arrow_board.dart';
import 'command.dart';

class CommandInvoker {
  // Each entry stores (command, boardBeforeExecute) for snapshot-based undo.
  final List<(ICommand, ArrowBoard)> _history = [];

  bool get canUndo => _history.isNotEmpty;

  ArrowBoard executeCommand(ICommand command, ArrowBoard board) {
    final newBoard = command.execute(board);
    _history.add((command, board));
    return newBoard;
  }

  /// Returns the board state that existed before the last command was executed.
  ArrowBoard undo(ArrowBoard currentBoard) {
    if (!canUndo) return currentBoard;
    final (_, boardBefore) = _history.removeLast();
    return boardBefore;
  }
}
