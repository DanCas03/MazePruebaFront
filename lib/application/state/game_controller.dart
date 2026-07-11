import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/value_objects/level_blueprint.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/services/i_ticker.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../../domain/game_core/value_objects/score.dart';
import '../../domain/game_core/value_objects/stars.dart';
import '../../domain/game_core/value_objects/strike_count.dart';
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
  final ITicker _ticker;

  // El reloj es opcional: por defecto un Null Object inerte (tests que no
  // ejercen el tiempo, niveles sin límite). El composition root inyecta el
  // reloj real (SystemTicker) y los tests de tiempo, uno falso controlado.
  GameController(this._generator, this._removeArrow, this._invoker,
      [this._ticker = const NullTicker()]);

  // Estado con alcance de partida (no de dominio).
  LevelId? _currentLevel;
  int _blockedNonce = 0;
  int _exitNonce = 0;
  StrikeCount _strikes = const StrikeCount(0);

  // Cuenta atrás del nivel (front#11). _remainingSeconds es null si el nivel no
  // tiene límite; _tickSub es la suscripción viva al reloj inyectado.
  int? _remainingSeconds;
  StreamSubscription<int>? _tickSub;

  // Cronómetro ascendente (front#16): segundos transcurridos y óptimo del nivel
  // (número de flechas) para computar Score/Stars al ganar.
  int _elapsedSeconds = 0;
  int _optimalMoves = 0;
  StreamSubscription<int>? _elapsedSub;

  @override
  Future<GameState> build() async {
    // Evita que el reloj siga corriendo si el notifier se destruye.
    ref.onDispose(() {
      _cancelTimer();
      _cancelElapsed();
    });
    return GameLoading();
  }

  Future<void> loadLevel(LevelId levelId) async {
    // Aseguramos que build() haya resuelto antes de mutar el estado.
    await future;
    _cancelTimer();
    _cancelElapsed();
    _currentLevel = levelId;
    _blockedNonce = 0;
    _exitNonce = 0;
    _strikes = const StrikeCount(0);
    _invoker.clear();

    // La dificultad la decide LevelBlueprint (dominio); el generador solo genera.
    final bp = LevelBlueprint.forLevel(levelId.number);
    _remainingSeconds = bp.timeLimitSec;
    final board = _generator.generate(
      cols: bp.cols,
      rows: bp.rows,
      arrowCount: bp.arrowCount,
      maxPathLen: bp.maxPathLen,
      seed: levelId.number, // determinista: mismo nivel ⇒ mismo tablero
    );
    _optimalMoves = board.arrows.length; // óptimo = nº de flechas del nivel
    _startElapsed();
    state = AsyncValue.data(
      GamePlaying(
        board: board,
        moves: const MoveCount(0),
        canUndo: false,
        remainingSeconds: _remainingSeconds,
      ),
    );

    // Niveles avanzados arrancan la cuenta atrás; al agotarse → GameLost.
    final limit = bp.timeLimitSec;
    if (limit != null) _startTimer(limit);
  }

  Future<void> tapArrow(ArrowId arrowId) async {
    final current = state.valueOrNull;
    if (current is! GamePlaying) return;

    final result = _removeArrow.execute(current.board, arrowId);
    result.fold(
      (_) {
        // Bloqueada o ausente → choque (ADR 0001 §6): al 5º se pierde;
        // antes, feedback de shake (sin cambiar el tablero).
        _strikes = _strikes.increment();
        if (_strikes.isFatal) {
          _cancelTimer();
          _cancelElapsed();
          state = AsyncValue.data(
            GameLost(moves: current.moves, strikes: _strikes),
          );
          return;
        }
        _blockedNonce++;
        state = AsyncValue.data(GamePlaying(
          board: current.board,
          moves: current.moves,
          strikes: _strikes,
          blockedArrow: arrowId,
          blockedNonce: _blockedNonce,
          exitNonce: _exitNonce,
          canUndo: _invoker.canUndo,
          remainingSeconds: _remainingSeconds,
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
          _cancelTimer();
          _cancelElapsed();
          // front#16: computa el resultado del run con los VOs de front#12.
          final score = Score.fromRun(
            time: Duration(seconds: _elapsedSeconds),
            moves: newMoves.value,
            optimalMoves: _optimalMoves,
            collisions: _strikes.value,
          );
          final stars = Stars.rate(
            moves: newMoves.value,
            optimalMoves: _optimalMoves,
            collisions: _strikes.value,
          );
          state = AsyncValue.data(GameWon(
            moves: newMoves,
            score: score,
            stars: stars,
            timeSeconds: _elapsedSeconds,
            levelId: _currentLevel!,
          ));
        } else {
          state = AsyncValue.data(GamePlaying(
            board: newBoard,
            moves: newMoves,
            strikes: _strikes,
            exitingArrow: removed,
            exitNonce: _exitNonce,
            blockedNonce: _blockedNonce,
            canUndo: _invoker.canUndo,
            remainingSeconds: _remainingSeconds,
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
      strikes: _strikes,
      blockedNonce: _blockedNonce,
      exitNonce: _exitNonce,
      canUndo: _invoker.canUndo,
      remainingSeconds: _remainingSeconds,
    ));
  }

  Future<void> restartLevel() async {
    final level = _currentLevel;
    if (level != null) {
      await loadLevel(level); // determinista ⇒ mismo tablero (reinicia el reloj)
    }
  }

  // ── Cuenta atrás inyectable (front#11) ──────────────────────────────────────

  void _startTimer(int seconds) {
    _cancelTimer();
    _remainingSeconds = seconds;
    _tickSub = _ticker.countdown(seconds: seconds).listen((remaining) {
      _remainingSeconds = remaining;
      final current = state.valueOrNull;
      // Si ya se ganó/perdió/salió de la partida, ignoramos el tick tardío.
      if (current is! GamePlaying) return;
      if (remaining <= 0) {
        _cancelTimer();
        _cancelElapsed();
        state = AsyncValue.data(
          GameLost(moves: current.moves, strikes: _strikes),
        );
      } else {
        state = AsyncValue.data(GamePlaying(
          board: current.board,
          moves: current.moves,
          strikes: current.strikes,
          blockedArrow: current.blockedArrow,
          blockedNonce: current.blockedNonce,
          exitingArrow: current.exitingArrow,
          exitNonce: current.exitNonce,
          canUndo: current.canUndo,
          remainingSeconds: remaining,
        ));
      }
    });
  }

  void _cancelTimer() {
    _tickSub?.cancel();
    _tickSub = null;
  }

  void _startElapsed() {
    _cancelElapsed();
    _elapsedSeconds = 0;
    _elapsedSub = _ticker.elapsed().listen((s) => _elapsedSeconds = s);
  }

  void _cancelElapsed() {
    _elapsedSub?.cancel();
    _elapsedSub = null;
  }
}
