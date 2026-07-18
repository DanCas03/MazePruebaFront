import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'game_controller_test.mocks.dart';

/// Nivel hex R=2 SIN silueta (ficha libre del modo hex): una única flecha
/// diagonal `downRight` de dos celdas dentro del hexágono. Quitarla vacía el
/// tablero ⇒ GameWon. Ejercita el motor real (RemoveArrowUseCase) sobre HexSpace.
ArrowBoard _hexBoard() => ArrowBoard(
      arrows: [
        Arrow(
          id: const ArrowId('h0'),
          headDirection: Direction.downRight,
          cells: [Position(row: 2, col: 2), Position(row: 2, col: 3)],
        ),
      ],
      space: const HexSpace(2),
    );

void main() {
  test('el flujo completo de partida corre sobre un nivel hex sin cambios en el motor', () async {
    // Arrange — GameController con el RemoveArrowUseCase REAL (no mock): el
    // motor resuelve canExit/remove sobre HexSpace vía polimorfismo, no rect.
    final repo = MockILevelRepository();
    when(repo.getLevel(any)).thenAnswer(
      (_) async => Right(Level(id: LevelId('hx'), board: _hexBoard())),
    );
    final container = ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(repo, RemoveArrowUseCase(), CommandInvoker()),
      ),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(gameControllerProvider.notifier);

    // Act — cargar el nivel y tocar la única flecha; el carril downRight hasta
    // la frontera del hex está libre, así que sale y el tablero queda vacío.
    await notifier.loadLevel(LevelId('hx'));
    final playing =
        container.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(playing.board.space, isA<HexSpace>()); // montado sobre hex
    await notifier.tapArrow(const ArrowId('h0'));

    // Assert — tap → canExit → remove → win, todo sobre geometría hexagonal.
    expect(container.read(gameControllerProvider).valueOrNull, isA<GameWon>());
  });
}
