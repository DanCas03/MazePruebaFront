import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/game_core/value_objects/move_count.dart';

// State Pattern (sealed): modela los estados mutuamente excluyentes del juego
// para que la UI haga pattern matching exhaustivo sin flags booleanos.
sealed class GameState {}

class GameLoading extends GameState {}

class GamePlaying extends GameState {
  final ArrowBoard board;
  final MoveCount moves;
  GamePlaying({required this.board, required this.moves});
}

class GameWon extends GameState {
  final MoveCount moves;
  GameWon({required this.moves});
}
