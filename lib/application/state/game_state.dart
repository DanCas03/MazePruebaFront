import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';

// State Pattern (sealed): estados mutuamente excluyentes del juego.
sealed class GameState {}

class GameLoading extends GameState {}

class GamePlaying extends GameState {
  final ArrowBoard board;
  final MoveCount moves;

  // Señales TRANSITORIAS de presentación (no son reglas de dominio):
  final ArrowId? blockedArrow; // última flecha tocada que no puede salir
  final int blockedNonce; // ++ por bloqueo → re-dispara el shake
  final Arrow? exitingArrow; // "fantasma" de la flecha recién removida
  final int exitNonce; // ++ por salida → re-dispara el slide-out
  final bool canUndo; // habilita el botón undo del top bar

  GamePlaying({
    required this.board,
    required this.moves,
    this.blockedArrow,
    this.blockedNonce = 0,
    this.exitingArrow,
    this.exitNonce = 0,
    this.canUndo = false,
  });
}

class GameWon extends GameState {
  final MoveCount moves;
  GameWon({required this.moves});
}
