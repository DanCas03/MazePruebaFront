// lib/application/commands/move_command.dart

import '../../domain/player/entities/player.dart';
import '../../domain/game_core/value_objects/position.dart';
import 'command.dart';

class MoveCommand implements ICommand {
  final Player player;
  final Position newPosition;

  // Guardamos esto para saber cómo revertir la acción
  MoveCommand({
    required this.player,
    required this.newPosition,
  });

  @override
  void execute() {
    // Usamos el método seguro que creamos en la entidad Player
    player.moveTo(newPosition);
  }

  @override
  void undo() {
    // La entidad Player ya sabe cómo deshacer su último paso
    player.undoLastMove();
  }
}