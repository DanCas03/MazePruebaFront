import '../../domain/arrows/entities/arrow_board.dart';

// Command Pattern: encapsula operaciones reversibles sobre ArrowBoard.
abstract interface class ICommand {
  ArrowBoard execute(ArrowBoard board);
  ArrowBoard undo(ArrowBoard board);
}
