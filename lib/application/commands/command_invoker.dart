// lib/application/commands/command_invoker.dart

import 'command.dart';

class CommandInvoker {
  // Historial global de todas las acciones del juego
  final List<ICommand> _history = [];

  /// Ejecuta cualquier comando y lo guarda en el historial
  void executeCommand(ICommand command) {
    command.execute();
    _history.add(command);
  }

  /// Deshace la última acción, sin importar si fue movimiento o rotación
  bool undoLastCommand() {
    if (_history.isEmpty) {
      return false; // No hay nada que deshacer
    }

    // Extraemos el último comando y le pedimos que se deshaga a sí mismo
    final lastCommand = _history.removeLast();
    lastCommand.undo();
    return true;
  }

  /// Útil para reiniciar el nivel
  void clearHistory() {
    _history.clear();
  }

  /// Útil para el sistema de puntuación (ej. 3 estrellas si lo pasas en menos de X movimientos)
  int get actionCount => _history.length;
}