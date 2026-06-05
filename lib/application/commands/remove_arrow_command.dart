// lib/application/commands/remove_arrow_command.dart

import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import 'command.dart';

/// Comando que saca una flecha del tablero, con soporte de deshacer.
///
/// Patrón Command: encapsula la acción "sacar flecha" y guarda la propia flecha
/// para poder reinsertarla en `undo()`. El [CommandInvoker] mantiene el
/// historial y permite deshacer la última salida.
class RemoveArrowCommand implements ICommand {
  final ArrowBoard board;
  final Arrow arrow;

  RemoveArrowCommand({required this.board, required this.arrow});

  @override
  void execute() => board.removeArrow(arrow.id);

  @override
  void undo() => board.addArrow(arrow);
}
