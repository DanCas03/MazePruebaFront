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

/// Tablero 4×4 con dos flechas. front#114: un nivel TEMÁTICO (con silueta) se
/// monta sobre un MaskedSpace cuya máscara es la FIGURA (unión de las celdas de
/// la silueta) — no la unión de las flechas (#88) ni la caja completa (#99).
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

/// Silueta de FIGURA por roles: cubre las flechas y añade celdas interiores
/// sin flecha ((1,1) y (1,2)) — la máscara debe ser su UNIÓN completa.
Map<String, List<Position>> _silhouette() => {
      'body': [
        Position(row: 0, col: 0),
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ],
      'tail': [
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
      ],
    };

Set<Position> _figureCells(Map<String, List<Position>> silhouette) =>
    {for (final cells in silhouette.values) ...cells};

void _stubLevel(MockILevelRepository repo, ArrowBoard board,
        {Map<String, String>? palette,
        Map<String, List<Position>>? silhouette}) =>
    when(repo.getLevel(any)).thenAnswer((_) async => Right(Level(
          id: LevelId('1'),
          board: board,
          palette: palette,
          silhouette: silhouette,
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
  test(
      'themed level (silhouette != null) mounts a MaskedSpace whose mask is the figure',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    final silhouette = _silhouette();
    _stubLevel(repo, _board(),
        palette: const {'body': '#ff0000', 'tail': '#00ff00'},
        silhouette: silhouette);
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — front#114: solo existen las celdas de la figura (unión de TODAS
    // las regiones de la silueta), en la misma caja cols×rows del wire.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(
      state.board.space,
      MaskedSpace(4, 4, activeCells: _figureCells(silhouette)),
    );
    expect(state.board.arrows.length, 2); // mismas flechas
  });

  test('themed level (silhouette != null) exposes it on GamePlaying state',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    final silhouette = {
      'body': [Position(row: 0, col: 0), Position(row: 0, col: 1)],
    };
    _stubLevel(repo, _board(),
        palette: const {'fill': '#ff0000'}, silhouette: silhouette);
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — front#114: la silueta viaja al estado de partida, espejo de palette.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.silhouette, isNotNull);
    expect(state.silhouette, silhouette);
  });

  test('campaign level (silhouette == null) keeps its RectSpace untouched',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board()); // sin silueta ni palette
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, RectSpace(4, 4));
  });

  test('restarting a themed level re-mounts the same figure MaskedSpace',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    final silhouette = _silhouette();
    _stubLevel(repo, _board(),
        palette: const {'body': '#00ff00', 'tail': '#0000ff'},
        silhouette: silhouette);
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act
    await notifier.restartLevel();

    // Assert — sin refetch, se re-monta la misma máscara de figura.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(
      state.board.space,
      MaskedSpace(4, 4, activeCells: _figureCells(silhouette)),
    );
  });
}
