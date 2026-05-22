import 'package:flutter/foundation.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../../domain/board/entities/board.dart';
import '../../../domain/player/entities/player.dart';
import '../../../application/commands/command_invoker.dart';
import '../../../application/use_cases/player/move_player_use_case.dart';
import '../../../application/use_cases/board/rotate_arrow_use_case.dart';
import '../../../application/use_cases/game_core/check_win_condition_use_case.dart';

// Al extender de ChangeNotifier, implementamos el Patrón Observer
class GameController extends ChangeNotifier {
  final Board board;
  final Player player;
  
  // Casos de uso inyectados
  final CommandInvoker _invoker;
  final MovePlayerUseCase _moveUseCase;
  final RotateArrowUseCase _rotateUseCase;
  final CheckWinConditionUseCase _winUseCase;

  bool isVictory = false;

  GameController({
    required this.board,
    required this.player,
    required CommandInvoker invoker,
    required MovePlayerUseCase moveUseCase,
    required RotateArrowUseCase rotateUseCase,
    required CheckWinConditionUseCase winUseCase,
  })  : _invoker = invoker,
        _moveUseCase = moveUseCase,
        _rotateUseCase = rotateUseCase,
        _winUseCase = winUseCase;

  /// Se llama cuando el jugador desliza el dedo (Swipe)
  void onSwipe(Direction direction) {
    if (isVictory) return;

    bool moved = _moveUseCase.executeMove(direction);
    if (moved) {
      isVictory = _winUseCase.execute();
      notifyListeners(); // ¡Avisamos a los observadores (UI) que se redibujen!
    }
  }

  /// Se llama cuando el jugador toca una celda (Tap)
  void onCellTapped(Position position) {
    if (isVictory) return;

    bool rotated = _rotateUseCase.executeRotation(position);
    if (rotated) {
      notifyListeners();
    }
  }

  /// Conecta con el botón "Deshacer" de la UI
  void onUndoPressed() {
    if (_invoker.undoLastCommand()) {
      isVictory = false; // Por si deshace el paso ganador
      notifyListeners();
    }
  }
}