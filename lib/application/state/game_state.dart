import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../../domain/game_core/value_objects/score.dart';
import '../../domain/game_core/value_objects/stars.dart';
import '../../domain/game_core/value_objects/strike_count.dart';

// State Pattern (sealed): estados mutuamente excluyentes del juego.
sealed class GameState {}

class GameLoading extends GameState {}

class GamePlaying extends GameState {
  final ArrowBoard board;
  final MoveCount moves;
  final StrikeCount strikes; // choques acumulados; a los 5 → GameLost

  // Señales TRANSITORIAS de presentación (no son reglas de dominio):
  final ArrowId? blockedArrow; // última flecha tocada que no puede salir
  final int blockedNonce; // ++ por bloqueo → re-dispara el shake
  final Arrow? exitingArrow; // "fantasma" de la flecha recién removida
  final int exitNonce; // ++ por salida → re-dispara el slide-out
  final bool canUndo; // habilita el botón undo del top bar
  final int? remainingSeconds; // cuenta atrás del nivel; null si no tiene límite

  GamePlaying({
    required this.board,
    required this.moves,
    this.strikes = const StrikeCount(0),
    this.blockedArrow,
    this.blockedNonce = 0,
    this.exitingArrow,
    this.exitNonce = 0,
    this.canUndo = false,
    this.remainingSeconds,
  });
}

class GameWon extends GameState {
  final MoveCount moves;
  final Score score; // front#16: puntaje computado del run
  final Stars stars; // front#16: estrellas del run
  final int timeSeconds; // front#16: tiempo transcurrido, para el POST /scores
  final LevelId levelId; // front#16: nivel al que pertenece el score
  GameWon({
    required this.moves,
    required this.score,
    required this.stars,
    required this.timeSeconds,
    required this.levelId,
  });
}

class GameLost extends GameState {
  final MoveCount moves;
  final StrikeCount strikes;
  GameLost({required this.moves, required this.strikes});
}
