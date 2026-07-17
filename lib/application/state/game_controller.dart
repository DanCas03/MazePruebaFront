import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/entities/level.dart';
import '../../domain/board/failures/solution_failure.dart';
import '../../domain/board/repositories/i_level_repository.dart';
import '../../domain/board/repositories/i_solution_repository.dart';
import '../../domain/board/services/hint_policy.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/services/i_ticker.dart';
import '../../domain/game_core/space/masked_space.dart';
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
  final ILevelRepository _levelRepository;
  final RemoveArrowUseCase _removeArrow;
  final CommandInvoker _invoker;
  final ITicker _ticker;
  final ISolutionRepository _solutionRepository;
  final HintPolicy _hintPolicy;

  // Pausa entre pasos de la demo de la pista (#32): debe cubrir la animación de
  // salida (~360 ms) para que cada flecha se vea deslizarse. Inyectable a
  // Duration.zero en tests para reproducir la solución sin esperar tiempo real.
  final Duration hintStepDelay;

  // El reloj es opcional: por defecto un Null Object inerte (tests que no
  // ejercen el tiempo, niveles sin límite). El composition root inyecta el
  // reloj real (SystemTicker) y los tests de tiempo, uno falso controlado.
  //
  // El repo de solución (#32) también es opcional: por defecto un Null Object
  // que reporta "no disponible", para que un controlador sin componer degrade a
  // "pista no disponible" en vez de crashear. `main` inyecta el remoto real.
  GameController(
    this._levelRepository,
    this._removeArrow,
    this._invoker, [
    this._ticker = const NullTicker(),
    this._solutionRepository = const _UnavailableSolutionRepository(),
    this.hintStepDelay = const Duration(milliseconds: 420),
    this._hintPolicy = const HintPolicy(),
  ]);

  // Estado con alcance de partida (no de dominio).
  LevelId? _currentLevel;

  // Datos del nivel remoto en curso (spec §5.2). Restart lo reutiliza sin
  // refetch; undo-tras-victoria toma de aquí las dimensiones reales del tablero.
  Level? _currentLevelData;
  int _blockedNonce = 0;
  int _exitNonce = 0;
  StrikeCount _strikes = const StrikeCount(0);

  // Token de generación de la pista (#32): cada nueva pista, carga, reinicio o
  // disposición lo incrementa; la demo en vuelo lo comprueba tras cada await y
  // aborta si quedó superada (evita reproducir sobre un nivel que ya cambió).
  int _hintRun = 0;

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
    // Evita que el reloj siga corriendo si el notifier se destruye. Bumpea el
    // token de pista para que una demo en vuelo se detenga tras su próximo await.
    ref.onDispose(() {
      _hintRun++;
      _cancelTimer();
      _cancelElapsed();
    });
    return GameLoading();
  }

  // Fuente de nivel única: el puerto remoto (DIP). El "Strategy remoto/procedural"
  // de front#9 se descartó tras el cutover (ver README §"Campaña remota").
  Future<void> loadLevel(LevelId levelId) async {
    // build() ya resolvió, pero si una carga previa dejó el provider en
    // AsyncError, `future` está completado con ese error: lo ignoramos (se
    // sobrescribe con loading a continuación) para permitir el reintento.
    try {
      await future;
    } catch (_) {}
    _hintRun++; // invalida cualquier demo de pista en vuelo
    _cancelTimer();
    _cancelElapsed();
    state = const AsyncValue<GameState>.loading();
    final result = await _levelRepository.getLevel(levelId);
    result.fold(
      (failure) {
        // Reutilizamos el AsyncValue que ya envuelve GameState; sin caso nuevo
        // en el sealed. La UI discrimina el LevelFailure en la rama de error.
        _currentLevelData = null; // sin nivel jugable: restart no reusa el previo
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (level) {
        _currentLevel = levelId;
        _currentLevelData = level;
        _startLevel(level);
      },
    );
  }

  // Montaje (front#118): un nivel con silueta se juega sobre el MaskedSpace de
  // su figura — fuera de la silueta no hay tablero (spec 2026-07-16). Campaña y
  // niveles sin silueta conservan su RectSpace del wire. Revierte la decisión
  // "caja completa" de front#99/#107 SOLO para temáticos con silueta.
  ArrowBoard _mountedBoard(Level level) {
    final active = level.silhouetteUnion;
    if (active == null) return level.board;
    final box = level.board.space.bounds;
    return level.board.remountedOn(
      MaskedSpace(box.cols, box.rows, activeCells: active),
    );
  }

  // Monta el nivel [level] en el estado de partida. Reutilizado por loadLevel
  // (tras el fetch) y por restartLevel (sin refetch). Arranca el cronómetro y,
  // si el nivel es cronometrado, la cuenta atrás.
  void _startLevel(Level level) {
    _cancelTimer();
    _cancelElapsed();
    _blockedNonce = 0;
    _exitNonce = 0;
    // Presupuesto de errores POR NIVEL (front#83): el contador arranca lleno y
    // desciende con cada choque; a los cero errores restantes se pierde.
    _strikes = StrikeCount(0, max: level.maxErrors);
    _invoker.clear();
    _remainingSeconds = level.timeLimitSec;
    final board = _mountedBoard(level);
    _optimalMoves = board.arrows.length; // óptimo = nº de flechas
    _startElapsed();
    state = AsyncValue.data(GamePlaying(
      board: board,
      moves: const MoveCount(0),
      strikes: _strikes, // expone el presupuesto del nivel al HUD desde el inicio
      palette: level.palette,
      canUndo: false,
      remainingSeconds: _remainingSeconds,
    ));
    final limit = level.timeLimitSec;
    if (limit != null) _startTimer(limit);
  }

  Future<void> tapArrow(ArrowId arrowId) async {
    final current = state.valueOrNull;
    if (current is! GamePlaying) return;
    // Durante la pista (carga o reproducción) el input está bloqueado: la demo
    // es no interactiva y no debe contar movimientos ni choques.
    if (current.hintLoading || current.hintPlaying) return;

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
          palette: _currentLevelData?.palette,
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
            timeLimitSec: _currentLevelData?.timeLimitSec,
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
            collisions: _strikes.value,
          ));
        } else {
          state = AsyncValue.data(GamePlaying(
            board: newBoard,
            moves: newMoves,
            strikes: _strikes,
            palette: _currentLevelData?.palette,
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
    // Undo bloqueado mientras la pista está en carga o reproducción (#32).
    if (current is GamePlaying && (current.hintLoading || current.hintPlaying)) {
      return;
    }

    final ArrowBoard currentBoard;
    final int currentMoves;
    if (current is GamePlaying) {
      currentBoard = current.board;
      currentMoves = current.moves.value;
    } else if (current is GameWon) {
      // Tras la victoria el tablero quedó vacío; reconstruimos uno vacío con las
      // dimensiones REALES del nivel remoto para reinsertar bien.
      final data = _currentLevelData;
      if (data == null) return;
      // Reconstruimos vacío con el MISMO espacio con que se montó el nivel
      // (front#118: la silueta en los temáticos, la caja en campaña), no el
      // crudo del wire: solo interesa su `space`.
      currentBoard =
          ArrowBoard(arrows: const [], space: _mountedBoard(data).space);
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
      palette: _currentLevelData?.palette,
      blockedNonce: _blockedNonce,
      exitNonce: _exitNonce,
      canUndo: _invoker.canUndo,
      remainingSeconds: _remainingSeconds,
    ));
  }

  Future<void> restartLevel() async {
    final level = _currentLevelData;
    if (level == null) return;
    _hintRun++; // aborta una demo de pista en vuelo antes de remontar
    _startLevel(level); // sin refetch: mismo Level cacheado
  }

  // ── Pista auto-resolutora (#32) ─────────────────────────────────────────────

  /// Pide la Solución del nivel al back y reproduce la demo no puntuable. Flujo:
  /// 1) sub-estado de carga (bombilla transformada, anti doble-clic) mientras la
  ///    petición HTTP viaja; 2) si falla/expira, rompe limpio conservando la
  ///    partida y dispara el snackbar; 3) si llega, remonta el tablero y anima
  ///    la salida de cada flecha en el orden del servidor —verbatim, sin derivar
  ///    nada—; 4) al terminar, reinicia el nivel para que quede jugable.
  Future<void> playHint() async {
    final level = _currentLevelData;
    final levelId = _currentLevel;
    final current = state.valueOrNull;
    if (level == null || levelId == null || current is! GamePlaying) return;
    // Anti doble-clic: ya hay una petición o una reproducción en curso.
    if (current.hintLoading || current.hintPlaying) return;
    // Política: la pista solo existe en niveles elegibles (guarda defensiva; la
    // UI ya oculta el botón fuera de ellos). Los temáticos (con Instrucciones de
    // pintado) son siempre elegibles — señal por `palette`, no por el id.
    if (!_hintPolicy.isEligible(levelId, themed: level.palette != null)) return;

    final run = ++_hintRun;
    // Sub-estado de carga: transforma la bombilla y bloquea el botón.
    state = AsyncValue.data(_withHint(current, loading: true));

    final result = await _solutionRepository.getSolution(levelId);
    // La partida pudo cambiar mientras la solución viajaba (otra carga/reinicio,
    // disposición, o timeout que llevó a GameLost): aborta sin tocar el estado.
    if (run != _hintRun) return;
    final now = state.valueOrNull;
    if (now is! GamePlaying) return;

    if (result.isLeft()) {
      // Rompe limpio: quita la carga, conserva la partida intacta y avisa vía
      // el nonce (la UI muestra el snackbar de error).
      state = AsyncValue.data(_withHint(now, loading: false, bumpError: true));
      return;
    }
    final order = result.getOrElse(() => const <ArrowId>[]);
    await _runHintDemo(level, order, run);
  }

  Future<void> _runHintDemo(Level level, List<ArrowId> order, int run) async {
    // Demo no puntuable: congela reloj y cronómetro y NO toca el invoker (la
    // pila de undo queda intacta) ni cuenta movimientos/choques.
    _cancelTimer();
    _cancelElapsed();
    var board = _mountedBoard(level);
    _exitNonce = 0;
    // Remonta el tablero completo antes de empezar a vaciarlo.
    state = AsyncValue.data(GamePlaying(
      board: board,
      moves: const MoveCount(0),
      strikes: StrikeCount(0, max: level.maxErrors), // HUD coherente con el nivel
      palette: level.palette,
      hintPlaying: true,
    ));
    await Future<void>.delayed(hintStepDelay);
    if (run != _hintRun) return;

    for (final id in order) {
      final removed = board.arrowById(id);
      // El back manda ids en orden de vaciado; si alguno ya no está, se salta
      // sin derivar orden alguno (contrato: reproducir verbatim).
      if (removed == null) continue;
      board = board.removeArrow(id);
      _exitNonce++;
      // Reutiliza el canal de animación de salida (exitingArrow + exitNonce).
      state = AsyncValue.data(GamePlaying(
        board: board,
        moves: const MoveCount(0),
        strikes: StrikeCount(0, max: level.maxErrors),
        palette: level.palette,
        hintPlaying: true,
        exitingArrow: removed,
        exitNonce: _exitNonce,
      ));
      await Future<void>.delayed(hintStepDelay);
      if (run != _hintRun) return;
    }

    // Fin de la demo: el nivel se reinicia y queda jugable de nuevo.
    if (run != _hintRun) return;
    _startLevel(level);
  }

  // Copia [s] cambiando solo las señales de pista, conservando el resto del
  // estado de partida (tablero, movimientos, choques, nonces, reloj) intactos.
  GamePlaying _withHint(
    GamePlaying s, {
    required bool loading,
    bool bumpError = false,
  }) =>
      GamePlaying(
        board: s.board,
        moves: s.moves,
        strikes: s.strikes,
        palette: s.palette,
        blockedArrow: s.blockedArrow,
        blockedNonce: s.blockedNonce,
        exitingArrow: s.exitingArrow,
        exitNonce: s.exitNonce,
        canUndo: s.canUndo,
        remainingSeconds: s.remainingSeconds,
        hintLoading: loading,
        hintPlaying: s.hintPlaying,
        hintErrorNonce: bumpError ? s.hintErrorNonce + 1 : s.hintErrorNonce,
      );

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
          palette: current.palette,
          blockedArrow: current.blockedArrow,
          blockedNonce: current.blockedNonce,
          exitingArrow: current.exitingArrow,
          exitNonce: current.exitNonce,
          canUndo: current.canUndo,
          remainingSeconds: remaining,
          // Preserva la carga de pista si un tick llega mientras la solución
          // viaja (la reproducción cancela el reloj, así que no coincide con él).
          hintLoading: current.hintLoading,
          hintPlaying: current.hintPlaying,
          hintErrorNonce: current.hintErrorNonce,
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

/// Null Object del puerto de solución: repo por defecto cuando el controlador no
/// se compone con uno real (tests que no ejercen la pista). Reporta siempre
/// "no disponible" para degradar con gracia en vez de crashear.
class _UnavailableSolutionRepository implements ISolutionRepository {
  const _UnavailableSolutionRepository();

  @override
  Future<Either<SolutionFailure, List<ArrowId>>> getSolution(LevelId id) async =>
      const Left(SolutionUnavailable());
}
