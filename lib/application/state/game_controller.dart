import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/value_objects/level_blueprint.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../commands/command_invoker.dart';
import '../commands/remove_arrow_command.dart';
import '../use_cases/remove_arrow_use_case.dart';
import 'game_state.dart';

// El provider se compone en core/ (DI) o se sobreescribe en tests; la fábrica
// por defecto falla explícitamente para no acoplar este archivo a impls
// concretas (DIP) antes de que existan.
final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(
  () => throw UnimplementedError(
    'gameControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva (Riverpod) entre la UI y los casos de uso de dominio.
class GameController extends AsyncNotifier<GameState> {
  final ILevelGenerator _generator;
  final RemoveArrowUseCase _removeArrow;
  final CommandInvoker _invoker;

  GameController(this._generator, this._removeArrow, this._invoker);

  // Estado con alcance de partida (no de dominio).
  LevelId? _currentLevel;
  int _blockedNonce = 0;
  int _exitNonce = 0;

  @override
  Future<GameState> build() async => GameLoading();

  Future<void> loadLevel(LevelId levelId) async {
    // Aseguramos que build() haya resuelto antes de mutar el estado.
    await future;
    _currentLevel = levelId;
    _blockedNonce = 0;
    _exitNonce = 0;
    _invoker.clear();

    // La dificultad la decide LevelBlueprint (dominio); el generador solo genera.
    final bp = LevelBlueprint.forLevel(levelId.number);
    final board = _generator.generate(
      cols: bp.cols,
      rows: bp.rows,
      arrowCount: bp.arrowCount,
      maxPathLen: bp.maxPathLen,
      seed: levelId.number, // determinista: mismo nivel ⇒ mismo tablero
    );
    state = AsyncValue.data(
      GamePlaying(board: board, moves: const MoveCount(0), canUndo: false),
    );
  }

  Future<void> tapArrow(ArrowId arrowId) async {
    final current = state.valueOrNull;
    if (current is! GamePlaying) return;

    final result = _removeArrow.execute(current.board, arrowId);
    result.fold(
      (_) {
        // Bloqueada o ausente → feedback de shake (sin cambiar el tablero).
        _blockedNonce++;
        state = AsyncValue.data(GamePlaying(
          board: current.board,
          moves: current.moves,
          blockedArrow: arrowId,
          blockedNonce: _blockedNonce,
          exitNonce: _exitNonce,
          canUndo: _invoker.canUndo,
        ));
      },
      (_) {
        // Legal: captura la flecha (para el fantasma de salida) y la remueve
        // por Command para mantener el historial de undo coherente.
        final removed = current.board.arrowById(arrowId);
        final cmd = RemoveArrowCommand(arrowId);
        final newBoard = _invoker.executeCommand(cmd, current.board);
        final newMoves = current.moves.increment();
        _exitNonce++;
        if (newBoard.isCleared) {
          state = AsyncValue.data(GameWon(moves: newMoves));
        } else {
          state = AsyncValue.data(GamePlaying(
            board: newBoard,
            moves: newMoves,
            exitingArrow: removed,
            exitNonce: _exitNonce,
            blockedNonce: _blockedNonce,
            canUndo: _invoker.canUndo,
          ));
        }
      },
    );
  }

  Future<void> undoMove() async {
    if (!_invoker.canUndo) return;
    final current = state.valueOrNull;

    final ArrowBoard currentBoard;
    final int currentMoves;
    if (current is GamePlaying) {
      currentBoard = current.board;
      currentMoves = current.moves.value;
    } else if (current is GameWon) {
      // Tras la victoria el tablero quedó vacío; reconstruimos uno vacío con
      // las dimensiones REALES del nivel (no 4x4 fijo) para reinsertar bien.
      final bp = LevelBlueprint.forLevel((_currentLevel ?? LevelId('1')).number);
      currentBoard = ArrowBoard(arrows: const [], cols: bp.cols, rows: bp.rows);
      currentMoves = current.moves.value;
    } else {
      return;
    }

    final previousBoard = _invoker.undo(currentBoard);
    final previousMoves = MoveCount(currentMoves > 0 ? currentMoves - 1 : 0);
    state = AsyncValue.data(GamePlaying(
      board: previousBoard,
      moves: previousMoves,
      blockedNonce: _blockedNonce,
      exitNonce: _exitNonce,
      canUndo: _invoker.canUndo,
    ));
  }

  Future<void> restartLevel() async {
    final level = _currentLevel;
    if (level != null) {
      await loadLevel(level); // determinista ⇒ mismo tablero
    }
  }
}
