import '../../domain/arrows/entities/arrow_board.dart';
import 'command.dart';

/// Command Pattern invoker: keeps a history of [ICommand]s and delegates undo
/// back to each command so the reversal logic lives with the operation itself.
class CommandInvoker {
  final List<ICommand> _history = [];

  bool get canUndo => _history.isNotEmpty;

  ArrowBoard executeCommand(ICommand command, ArrowBoard board) {
    final newBoard = command.execute(board);
    _history.add(command);
    return newBoard;
  }

  /// Pops the last command and asks it to undo itself against the CURRENT
  /// board, returning the resulting state. Returns [currentBoard] unchanged
  /// when there is nothing to undo.
  ArrowBoard undo(ArrowBoard currentBoard) {
    if (!canUndo) return currentBoard;
    final command = _history.removeLast();
    return command.undo(currentBoard);
  }
}
