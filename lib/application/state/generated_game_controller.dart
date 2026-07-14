import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/arrows/value_objects/generated_board.dart';
import '../../domain/arrows/value_objects/generator_config.dart';
import '../../domain/game_core/services/i_ticker.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../../domain/game_core/value_objects/strike_count.dart';
import '../commands/command_invoker.dart';
import '../commands/remove_arrow_command.dart';
import '../use_cases/generate_board_use_case.dart';
import '../use_cases/remove_arrow_use_case.dart';
import 'game_state.dart';

// El provider se compone en el composition root (DIP) o se sobreescribe en
// tests; la fábrica por defecto falla explícitamente para no acoplar este
// archivo a impls concretas antes de que existan (mismo patrón que
// gameControllerProvider).
final generatedGameControllerProvider =
    AsyncNotifierProvider<GeneratedGameController, GameState>(
  () => throw UnimplementedError(
    'generatedGameControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva del flujo de tableros GENERADOS por el jugador (front#37).
///
/// CORTAFUEGOS DE PERSISTENCIA (spec §"Cero Persistencia"): a diferencia de
/// [GameController] (campaña), este controlador NO conoce `ILevelRepository`,
/// `SubmitScoreUseCase` ni `ILevelProgressRepository`. No puede escribir en
/// Hive, tocar el Progress local ni enviar al leaderboard porque no tiene
/// ningún colaborador capaz de hacerlo — el aislamiento es estructural, no un
/// flag en tiempo de ejecución. Reutiliza las MECÁNICAS de la campaña
/// ([RemoveArrowUseCase], [CommandInvoker], strikes, [ITicker]) y su tablero se
/// pinta con el mismo `BoardView`; solo el origen del tablero (generado, no
/// remoto) y el destino (sin puntuar) cambian.
class GeneratedGameController extends AsyncNotifier<GameState> {
  final GenerateBoardUseCase _generate;
  final RemoveArrowUseCase _removeArrow;
  final CommandInvoker _invoker;
  final ITicker _ticker;

  GeneratedGameController(
    this._generate,
    this._removeArrow,
    this._invoker, [
    this._ticker = const NullTicker(),
  ]);

  // Tablero + config EFECTIVA (con seed) de la sesión viva. Fuente de verdad
  // para las acciones post-partida ("Otro tablero"/"Repetir") y para mostrar la
  // semilla en el HUD. Efímero: vive en memoria, nunca se persiste.
  GeneratedBoard? _current;
  int _blockedNonce = 0;
  int _exitNonce = 0;
  StrikeCount _strikes = const StrikeCount(0);

  // Cuenta atrás derivada (front#11 reutilizado): null si el jugador no activó
  // el modo contrarreloj (spec: "aplica TimeLimit solo si se activó").
  int? _remainingSeconds;
  StreamSubscription<int>? _tickSub;

  /// Config efectiva de la sesión viva (tamaño/dificultad/timed/seed), o null
  /// si aún no se generó ningún tablero.
  GeneratorConfig? get currentConfig => _current?.config;

  /// Semilla del tablero vivo, o null si aún no se generó ninguno.
  int? get currentSeed => _current?.seed;

  @override
  Future<GameState> build() async {
    ref.onDispose(_cancelTimer);
    return GameLoading();
  }

  /// Genera y monta un tablero desde [config]. Si el jugador no fijó semilla, el
  /// caso de uso la completa y la deja en la config efectiva (reproducibilidad).
  ///
  /// Drena primero el `build()` asíncrono (que resuelve a [GameLoading]) con
  /// `await future`: si no, esa resolución tardía sobreescribiría el
  /// [GamePlaying] recién montado y el tablero nunca aparecería (mismo patrón
  /// que `GameController.loadLevel`).
  Future<void> startNew(GeneratorConfig config) async {
    try {
      await future;
    } catch (_) {}
    _mount(_generate.execute(config));
  }

  /// "Otro tablero" (spec): misma intención del jugador (tamaño/dificultad/
  /// timed) pero NUEVA semilla ⇒ tablero distinto. Reconstruye la config sin
  /// seed para que el caso de uso elija una nueva.
  Future<void> anotherBoard() async {
    final cfg = _current?.config;
    if (cfg == null) return;
    await startNew(GeneratorConfig.create(
      cols: cfg.cols,
      rows: cfg.rows,
      difficulty: cfg.difficulty,
      timed: cfg.timed,
    ));
  }

  /// "Repetir" (spec): misma semilla + misma config ⇒ tablero IDÉNTICO. La
  /// config efectiva ya lleva la seed, así que la generación es determinista.
  Future<void> repeat() async {
    final current = _current;
    if (current == null) return;
    await startNew(current.config);
  }

  void _mount(GeneratedBoard generated) {
    _cancelTimer();
    _blockedNonce = 0;
    _exitNonce = 0;
    _strikes = const StrikeCount(0);
    _invoker.clear();
    _current = generated;
    final limit = generated.config.timeLimitSec; // null si no contrarreloj
    _remainingSeconds = limit;
    state = AsyncValue.data(GamePlaying(
      board: generated.board,
      moves: const MoveCount(0),
      canUndo: false,
      remainingSeconds: _remainingSeconds,
    ));
    if (limit != null) _startTimer(limit);
  }

  Future<void> tapArrow(ArrowId arrowId) async {
    final current = state.valueOrNull;
    if (current is! GamePlaying) return;

    final result = _removeArrow.execute(current.board, arrowId);
    result.fold(
      (_) {
        // Choque (ADR 0001 §6): al 5º strike se pierde; antes, feedback de shake.
        _strikes = _strikes.increment();
        if (_strikes.isFatal) {
          _cancelTimer();
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
        final removed = current.board.arrowById(arrowId);
        final cmd = RemoveArrowCommand(arrowId);
        final newBoard = _invoker.executeCommand(cmd, current.board);
        final newMoves = current.moves.increment();
        _exitNonce++;
        if (newBoard.isCleared) {
          _cancelTimer();
          // Victoria SIN puntuar: estado terminal sin Score/Stars/LevelId.
          state = AsyncValue.data(GeneratedCleared(moves: newMoves));
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
    if (current is! GamePlaying) return;
    final previousBoard = _invoker.undo(current.board);
    final previousMoves =
        MoveCount(current.moves.value > 0 ? current.moves.value - 1 : 0);
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

  // ── Cuenta atrás inyectable (front#11 reutilizado) ──────────────────────────

  void _startTimer(int seconds) {
    _cancelTimer();
    _remainingSeconds = seconds;
    _tickSub = _ticker.countdown(seconds: seconds).listen((remaining) {
      _remainingSeconds = remaining;
      final current = state.valueOrNull;
      if (current is! GamePlaying) return; // ignora ticks tardíos tras terminar
      if (remaining <= 0) {
        _cancelTimer();
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
}
