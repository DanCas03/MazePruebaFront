import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../commands/command_invoker.dart';
import '../commands/remove_arrow_command.dart';
import '../use_cases/remove_arrow_use_case.dart';
import 'game_state.dart';

// El provider se compone en core/ (DI) o se sobreescribe en tests; la fábrica
// por defecto falla explícitamente para no acoplar este archivo a impls
// concretas (DIP) antes de que existan (p. ej. ILevelGenerator real).
final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(
  () => throw UnimplementedError(
    'gameControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva (Riverpod) entre la UI y los casos de uso de dominio.
///
/// Las dependencias se inyectan por constructor (DIP) para que los use cases y
/// el invoker permanezcan libres del framework y sustituibles en tests.
class GameController extends AsyncNotifier<GameState> {
  final ILevelGenerator _generator;
  final RemoveArrowUseCase _removeArrow;
  final CommandInvoker _invoker;

  GameController(this._generator, this._removeArrow, this._invoker);

  @override
  Future<GameState> build() async => GameLoading();

  Future<void> loadLevel(LevelId levelId) async {
    // Aseguramos que build() haya resuelto antes de mutar el estado: de lo
    // contrario su microtask sobreescribiría el GamePlaying recién fijado.
    await future;
    final board = _generator.generate(cols: 4, rows: 4, arrowCount: 5);
    state = AsyncValue.data(GamePlaying(board: board, moves: const MoveCount(0)));
  }

  Future<void> tapArrow(ArrowId arrowId) async {
    final current = state.valueOrNull;
    if (current is! GamePlaying) return;

    // El use case valida la jugada (flecha presente y salida libre). Solo si
    // es legal se materializa la mutación reversible vía Command + invoker, de
    // modo que el historial de undo refleje exactamente las jugadas aplicadas.
    final result = _removeArrow.execute(current.board, arrowId);
    result.fold(
      (_) {}, // arrow blocked or absent — no state change
      (_) {
        final cmd = RemoveArrowCommand(arrowId);
        final newBoard = _invoker.executeCommand(cmd, current.board);
        final newMoves = current.moves.increment();
        if (newBoard.isCleared) {
          state = AsyncValue.data(GameWon(moves: newMoves));
        } else {
          state = AsyncValue.data(GamePlaying(board: newBoard, moves: newMoves));
        }
      },
    );
  }

  Future<void> undoMove() async {
    final current = state.valueOrNull;
    if (current is! GamePlaying && current is! GameWon) return;
    if (!_invoker.canUndo) return;

    // Tras una victoria el tablero quedó vacío; el Command reinserta la flecha
    // sobre ese tablero para reconstruir el estado jugable anterior.
    final currentBoard = current is GamePlaying
        ? current.board
        : const ArrowBoard(arrows: [], cols: 4, rows: 4);
    final previousBoard = _invoker.undo(currentBoard);
    final previousMoves = current is GamePlaying
        ? MoveCount(current.moves.value - 1)
        : const MoveCount(0);
    state = AsyncValue.data(
      GamePlaying(board: previousBoard, moves: previousMoves),
    );
  }
}
