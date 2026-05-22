// lib/application/use_cases/player/move_player_use_case.dart

import '../../domain/board/entities/board.dart';
import '../../domain/player/entities/player.dart';
import '../../domain/game_core/value_objects/position.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../commands/command_invoker.dart'; // Importamos el Invocador
import '../../commands/move_command.dart';

class MovePlayerUseCase {
  final Player player;
  final Board board;
  
  // 1. Inyectamos la dependencia del Invocador
  final CommandInvoker invoker; 

  MovePlayerUseCase({
    required this.player, 
    required this.board, 
    required this.invoker,
  });

  /// Intenta mover al jugador en una dirección dada.
  bool executeMove(Direction direction) {
    final currentPos = player.currentPosition;
    Position targetPos = _calculateTargetPosition(currentPos, direction);

    // Reglas de Negocio
    final targetCell = board.getCellAt(targetPos);

    if (targetCell == null || !targetCell.isPassable) {
      return false; // Movimiento inválido
    }

    // 2. Orquestación: Creamos el comando y se lo pasamos al Invocador global
    final command = MoveCommand(player: player, newPosition: targetPos);
    invoker.executeCommand(command);

    return true;
  }

  // Nota: Eliminamos el método undoMove() de esta clase, ya que ahora 
  // la UI llamará directamente a invoker.undoLastCommand()

  // --- Lógica Auxiliar Privada ---
  Position _calculateTargetPosition(Position current, Direction dir) {
    switch (dir) {
      case Direction.up:
        return Position(x: current.x, y: current.y - 1);
      case Direction.down:
        return Position(x: current.x, y: current.y + 1);
      case Direction.left:
        return Position(x: current.x - 1, y: current.y);
      case Direction.right:
        return Position(x: current.x + 1, y: current.y);
    }
  }
}