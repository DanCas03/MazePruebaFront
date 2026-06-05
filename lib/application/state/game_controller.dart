// lib/application/state/game_controller.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aspects/i_logger_service.dart';
import '../../core/constants/durations.dart';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/board/entities/level_progress_entry.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/game_core/value_objects/arrow_id.dart';
import '../../domain/game_core/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../commands/command_invoker.dart';
import '../providers/dependency_providers.dart';
import '../use_cases/arrows/remove_arrow_use_case.dart';
import 'game_state.dart';

/// Controlador del juego (Riverpod `Notifier`).
///
/// Clean Architecture: vive en Aplicación y depende solo de abstracciones
/// (puerto del generador, repositorio de progreso y logger) inyectadas vía
/// `ref`. No importa Flutter Material ni infraestructura concreta.
class GameController extends Notifier<GameState> {
  late final ILevelGenerator _generator;
  late final ILevelProgressRepository _progressRepo;
  late final ILoggerService _logger;

  // Estado con alcance de partida.
  ArrowBoard? _board;
  CommandInvoker? _invoker;
  RemoveArrowUseCase? _useCase;
  LevelId? _levelId;
  int _moves = 0;
  int _blockedNonce = 0;
  int _exitNonce = 0;

  @override
  GameState build() {
    _generator = ref.read(levelGeneratorProvider);
    _progressRepo = ref.read(levelProgressRepositoryProvider);
    _logger = ref.read(loggerServiceProvider);
    return const GameLoading();
  }

  /// Genera el tablero del nivel y comienza la partida.
  void loadLevel(LevelId levelId) {
    state = const GameLoading();
    _levelId = levelId;
    _board = _generator.generate(levelId);
    _invoker = CommandInvoker();
    _useCase = RemoveArrowUseCase(board: _board!, invoker: _invoker!);
    _moves = 0;
    _blockedNonce = 0;
    _logger.log(
      'Nivel ${levelId.value} generado con ${_board!.remaining} flechas',
      tag: 'GameController',
    );
    _emitPlaying();
  }

  /// Intenta sacar la flecha tocada.
  void onArrowTapped(ArrowId id) {
    if (state is! GamePlaying) return;

    final result = _useCase!.execute(id);
    switch (result.outcome) {
      case RemoveArrowOutcome.removed:
        _moves++;
        _exitNonce++;
        // El tablero ya no contiene la flecha; la mostramos como "saliente"
        // para que la UI la anime deslizándose fuera de la pantalla.
        _emitPlaying(exitingArrow: result.arrow);
        if (result.boardCleared) {
          // Diferimos la victoria hasta que termine la animación de salida.
          unawaited(_scheduleWin());
        }
      case RemoveArrowOutcome.blocked:
        _blockedNonce++;
        _emitPlaying(blockedArrow: id);
      case RemoveArrowOutcome.notFound:
        break;
    }
  }

  Future<void> _scheduleWin() async {
    await Future<void>.delayed(kArrowExitDuration);
    if (_board != null && _board!.isCleared && state is GamePlaying) {
      _handleWin();
    }
  }

  /// Deshace la última salida de flecha.
  void onUndo() {
    if (state is! GamePlaying) return;
    if (_invoker!.undoLastCommand()) {
      _emitPlaying();
    }
  }

  /// Reinicia el nivel actual (regenera el mismo tablero determinista).
  void onRestart() {
    final level = _levelId;
    if (level != null) loadLevel(level);
  }

  // --- Helpers privados ---

  void _emitPlaying({ArrowId? blockedArrow, Arrow? exitingArrow}) {
    state = GamePlaying(
      board: _board!,
      movesUsed: _moves,
      canUndo: _invoker!.actionCount > 0,
      blockedArrow: blockedArrow,
      blockedNonce: _blockedNonce,
      exitingArrow: exitingArrow,
      exitNonce: _exitNonce,
    );
  }

  void _handleWin() {
    final moves = MoveCount(_moves);
    _logger.log(
      'Nivel ${_levelId!.value} completado en ${moves.value} movimientos',
      tag: 'GameController',
    );
    unawaited(_persistWin(moves));
    state = GameWon(moves: moves);
  }

  Future<void> _persistWin(MoveCount moves) async {
    try {
      final existing = await _progressRepo.loadProgress(_levelId!);
      final entry = (existing ??
              LevelProgressEntry(
                levelId: _levelId!,
                isCompleted: true,
                bestMoveCount: moves,
              ))
          .withBestMove(moves);
      await _progressRepo.saveProgress(entry);
    } catch (e, st) {
      _logger.error(
        'No se pudo guardar el progreso del nivel ${_levelId!.value}',
        tag: 'GameController',
        error: e,
        stackTrace: st,
      );
    }
  }
}
