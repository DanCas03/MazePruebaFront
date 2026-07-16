import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'game_controller_test.mocks.dart';
import '../../support/arrow_fixtures.dart';

/// Tablero 4×4 con dos flechas: la unión de sus celdas es la silueta esperada.
///   arrow-0: (0,0)-(0,1)   arrow-2: (2,2)-(2,3)
ArrowBoard _board() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('arrow-0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        straightArrow(
          id: const ArrowId('arrow-2'),
          tail: Position(row: 2, col: 2),
          direction: Direction.right,
          length: 2,
        ),
      ],
      space: RectSpace(4, 4),
    );

final _expectedMask = MaskedSpace(4, 4, activeCells: {
  Position(row: 0, col: 0),
  Position(row: 0, col: 1),
  Position(row: 2, col: 2),
  Position(row: 2, col: 3),
});

void _stubLevel(MockILevelRepository repo, ArrowBoard board,
        {Map<String, String>? palette}) =>
    when(repo.getLevel(any)).thenAnswer((_) async => Right(Level(
          id: LevelId('1'),
          board: board,
          palette: palette,
        )));

ProviderContainer _container(MockILevelRepository repo, MockRemoveArrowUseCase uc) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(repo, uc, CommandInvoker())),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('themed level (palette != null) mounts a MaskedSpace = union of arrow cells',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(), palette: const {'fill': '#ff0000'});
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — el tablero jugable se realiza como su silueta.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, _expectedMask);
    expect(state.board.arrows.length, 2); // mismas flechas
  });

  test('campaign level (palette == null) keeps its RectSpace untouched', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board()); // sin palette
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, RectSpace(4, 4));
  });

  test('restarting a themed level re-mounts the same MaskedSpace', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(), palette: const {'fill': '#00ff00'});
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act
    await notifier.restartLevel();

    // Assert — sin refetch, la silueta se re-deriva idéntica.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, _expectedMask);
  });
}
