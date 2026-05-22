// lib/application/use_cases/board/rotate_arrow_use_case.dart

import '../../domain/board/entities/board.dart';
import '../../domain/game_core/value_objects/position.dart';
import '../../commands/command_invoker.dart';
import '../../commands/rotate_command.dart';

class RotateArrowUseCase {
  final Board board;
  final CommandInvoker invoker; // Inyectamos el Invocador central

  RotateArrowUseCase({required this.board, required this.invoker});

  bool executeRotation(Position targetPosition) {
    final targetCell = board.getCellAt(targetPosition);

    if (targetCell == null) return false;

    // En lugar de ejecutarlo aquí, se lo pasamos al Invocador
    final command = RotateCommand(cell: targetCell);
    invoker.executeCommand(command);

    return true;
  }
}