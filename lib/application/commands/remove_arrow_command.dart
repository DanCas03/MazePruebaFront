import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/arrows/entities/arrow.dart';
import 'command.dart';

class RemoveArrowCommand implements ICommand {
  final ArrowId arrowId;
  Arrow? _removedArrow; // snapshot para undo

  RemoveArrowCommand(this.arrowId);

  @override
  ArrowBoard execute(ArrowBoard board) {
    _removedArrow = board.arrows.where((a) => a.id == arrowId).firstOrNull;
    return board.removeArrow(arrowId);
  }

  @override
  ArrowBoard undo(ArrowBoard board) {
    if (_removedArrow == null) return board;
    return ArrowBoard(
      arrows: [...board.arrows, _removedArrow!],
      cols: board.cols,
      rows: board.rows,
    );
  }
}
