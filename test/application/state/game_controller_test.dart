import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_blueprint.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'game_controller_test.mocks.dart';

@GenerateMocks([ILevelGenerator, RemoveArrowUseCase])
Arrow _arrow(String id, int col) => Arrow.straight(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: 2,
    );

/// Tablero 4x4 con dos flechas (no se vacía al quitar una).
ArrowBoard _twoArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0), _arrow('arrow-2', 2)], cols: 4, rows: 4);

/// Tablero 4x4 con una sola flecha (al quitarla queda limpio → victoria).
ArrowBoard _oneArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0)], cols: 4, rows: 4);

ProviderContainer _container(MockILevelGenerator gen, MockRemoveArrowUseCase uc) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(gen, uc, CommandInvoker())),
  ]);
  addTearDown(c.dispose);
  return c;
}

void _stubGenerate(MockILevelGenerator gen, ArrowBoard board) {
  when(gen.generate(
    cols: anyNamed('cols'),
    rows: anyNamed('rows'),
    arrowCount: anyNamed('arrowCount'),
    maxPathLen: anyNamed('maxPathLen'),
    seed: anyNamed('seed'),
  )).thenReturn(board);
}

void main() {
  test('loadLevel emite GamePlaying con el board generado y 0 movimientos', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    final board = _twoArrowBoard();
    _stubGenerate(gen, board);
    final c = _container(gen, uc);

    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GamePlaying>());
    expect((state as GamePlaying).moves.value, 0);
    expect(state.board, board);
    expect(state.canUndo, isFalse);
  });

  test('loadLevel usa las dimensiones del LevelBlueprint y seed = nivel', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    final c = _container(gen, uc);

    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('3'));

    final bp = LevelBlueprint.forLevel(3);
    verify(gen.generate(
            cols: bp.cols,
            rows: bp.rows,
            arrowCount: bp.arrowCount,
            maxPathLen: bp.maxPathLen,
            seed: 3))
        .called(1);
  });

  test('tapArrow bloqueada hace shake: blockedArrow seteada y blockedNonce sube', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('blocked')));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));
    final s1 = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s1.blockedArrow, const ArrowId('arrow-0'));
    expect(s1.blockedNonce, 1);
    expect(s1.board.arrows.length, 2); // no cambió el tablero

    await notifier.tapArrow(const ArrowId('arrow-0'));
    final s2 = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s2.blockedNonce, 2); // re-dispara
  });

  test('tapArrow legal remueve la flecha, +1 movimiento, exitingArrow y canUndo', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.moves.value, 1);
    expect(s.exitingArrow?.id, const ArrowId('arrow-0'));
    expect(s.exitNonce, 1);
    expect(s.canUndo, isTrue);
  });

  test('tapArrow que limpia el tablero emite GameWon', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));

    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GameWon>());
    expect((state as GameWon).moves.value, 1);
  });

  test('undoMove restaura el tablero y decrementa movimientos', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    await notifier.tapArrow(const ArrowId('arrow-0'));

    await notifier.undoMove();

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.board.arrows.length, 2); // flecha reinsertada
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
  });

  test('restartLevel limpia el historial y regenera (canUndo false, 0 movimientos)', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('2'));
    await notifier.tapArrow(const ArrowId('arrow-0'));

    await notifier.restartLevel();

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
    expect(s.board.arrows.length, 2);
  });
}
