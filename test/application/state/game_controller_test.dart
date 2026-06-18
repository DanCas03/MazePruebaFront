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
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'game_controller_test.mocks.dart';

ArrowBoard _boardWithArrow() {
  final a = Arrow(
    id: const ArrowId('a1'),
    tail: Position(row: 0, col: 0),
    direction: Direction.right,
    length: ArrowLength(2),
  );
  return ArrowBoard(arrows: [a], cols: 4, rows: 4);
}

@GenerateMocks([ILevelGenerator])
void main() {
  late MockILevelGenerator mockGenerator;
  late RemoveArrowUseCase useCase;
  late CommandInvoker invoker;

  setUp(() {
    mockGenerator = MockILevelGenerator();
    useCase = RemoveArrowUseCase();
    invoker = CommandInvoker();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(mockGenerator, useCase, invoker),
      ),
    ]);
  }

  group('GameController', () {
    test('loadLevel transitions from GameLoading to GamePlaying', () async {
      // Arrange
      when(mockGenerator.generate(cols: 4, rows: 4, arrowCount: 5))
          .thenReturn(_boardWithArrow());
      final container = makeContainer();
      // Act
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      // Assert
      final state = await container.read(gameControllerProvider.future);
      expect(state, isA<GamePlaying>());
    });

    test('tapArrow on a free path transitions to GameWon when board is cleared',
        () async {
      // Arrange
      when(mockGenerator.generate(cols: 4, rows: 4, arrowCount: 5))
          .thenReturn(_boardWithArrow());
      final container = makeContainer();
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      // Act
      await container
          .read(gameControllerProvider.notifier)
          .tapArrow(const ArrowId('a1'));
      // Assert
      final state = await container.read(gameControllerProvider.future);
      expect(state, isA<GameWon>());
    });

    test('undoMove restores previous GamePlaying state', () async {
      // Arrange
      when(mockGenerator.generate(cols: 4, rows: 4, arrowCount: 5))
          .thenReturn(_boardWithArrow());
      final container = makeContainer();
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      await container
          .read(gameControllerProvider.notifier)
          .tapArrow(const ArrowId('a1'));
      // Act
      await container.read(gameControllerProvider.notifier).undoMove();
      // Assert
      final state = await container.read(gameControllerProvider.future);
      expect(state, isA<GamePlaying>());
      expect((state as GamePlaying).board.arrows.length, 1);
    });
  });
}
