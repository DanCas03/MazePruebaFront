// lib/application/state/game_state.dart

import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/game_core/value_objects/arrow_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';

/// Estados del juego modelados como `sealed class` para un `switch` exhaustivo
/// en la UI. Pertenece a la capa de Aplicación: sin imports de Flutter.
sealed class GameState {
  const GameState();
}

/// Generando el tablero del nivel.
final class GameLoading extends GameState {
  const GameLoading();
}

/// Partida en curso.
///
/// - [board]: agregado con las flechas restantes.
/// - [movesUsed]: flechas sacadas con éxito (para la puntuación).
/// - [canUndo]: si hay alguna salida que deshacer.
/// - [blockedArrow] + [blockedNonce]: feedback cuando una flecha no puede salir;
///   el nonce cambia en cada intento bloqueado para re-disparar la animación de
///   "shake" aunque sea la misma flecha.
final class GamePlaying extends GameState {
  final ArrowBoard board;
  final int movesUsed;
  final bool canUndo;
  final ArrowId? blockedArrow;
  final int blockedNonce;

  /// Flecha que acaba de salir con éxito (ya retirada del [board]); la UI la
  /// anima deslizándose fuera de la pantalla. [exitNonce] cambia en cada salida
  /// para re-disparar la animación.
  final Arrow? exitingArrow;
  final int exitNonce;

  const GamePlaying({
    required this.board,
    required this.movesUsed,
    required this.canUndo,
    this.blockedArrow,
    this.blockedNonce = 0,
    this.exitingArrow,
    this.exitNonce = 0,
  });
}

/// Tablero limpio: nivel completado.
final class GameWon extends GameState {
  final MoveCount moves;

  const GameWon({required this.moves});
}
