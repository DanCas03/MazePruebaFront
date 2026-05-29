import '../../../domain/board/entities/board.dart';
import '../../../domain/board/entities/exit_cell.dart';
import '../../../domain/player/entities/player.dart';

class CheckWinConditionUseCase {
  final Player player;
  final Board board;

  CheckWinConditionUseCase({
    required this.player,
    required this.board,
  });

  /// Ejecuta la validación de victoria.
  /// Se debe llamar después de cada movimiento exitoso del jugador.
  bool execute() {
    // 1. Obtenemos dónde está parado el jugador en este instante
    final currentPos = player.currentPosition;
    
    // 2. Le preguntamos al tablero qué hay en esa coordenada
    final currentCell = board.getCellAt(currentPos);

    // 3. Regla de negocio: Si la celda es de tipo ExitCell, ¡Ganó!
    return currentCell is ExitCell;
  }
}