import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/arrows/entities/arrow.dart';
import 'command.dart';

/// Command que elimina una flecha del tablero y la recuerda para poder
/// reinsertarla en [undo].
///
/// Instancias single-use: [execute] captura la flecha eliminada en
/// [_removedArrow]; [undo] la reinserta en el tablero ACTUAL recibido. Llamar
/// [undo] antes de [execute] (sin flecha capturada) devuelve el tablero sin
/// cambios. Reutilizar la misma instancia para varias operaciones sobrescribe
/// el snapshot, por lo que se debe crear un comando por acción.
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
