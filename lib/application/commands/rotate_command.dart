// lib/application/commands/rotate_command.dart

import '../../domain/board/entities/cell.dart';
import 'command.dart';

class RotateCommand implements ICommand {
  final ICell cell;

  RotateCommand({required this.cell});

  @override
  void execute() {
    // Gracias al polimorfismo, no nos importa si es una pared, una celda vacía o una flecha.
    // Simplemente le decimos: "Interactúa".
    cell.interact();
  }

  @override
  void undo() {
    // Deshacemos la rotación (1 giro a la derecha se deshace con 3 giros más a la derecha)
    cell.interact();
    cell.interact();
    cell.interact();
  }
}