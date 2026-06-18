import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

/// Generador falso: devuelve un tablero fijo con dos flechas con salida libre,
/// suficiente para verificar el render del tablero y el toque de una pieza sin
/// depender del generador procedimental real.
class _FakeLevelGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
  }) {
    return ArrowBoard(
      cols: 4,
      rows: 4,
      arrows: [
        Arrow(
          id: const ArrowId('a1'),
          tail: Position(row: 0, col: 0),
          direction: Direction.left,
          length: ArrowLength(1),
        ),
        Arrow(
          id: const ArrowId('a2'),
          tail: Position(row: 1, col: 0),
          direction: Direction.left,
          length: ArrowLength(1),
        ),
      ],
    );
  }
}

ProviderContainer _container() => ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
          _FakeLevelGenerator(),
          RemoveArrowUseCase(),
          CommandInvoker(),
        ),
      ),
    ]);

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: Center(child: BoardWidget())),
      ),
    );

void main() {
  group('BoardWidget', () {
    testWidgets('renders nothing while not playing', (tester) async {
      // Arrange
      final container = _container();
      addTearDown(container.dispose);

      // Act
      await tester.pumpWidget(_host(container));

      // Assert — still GameLoading: no arrows on screen
      expect(find.byType(ArrowWidget), findsNothing);
    });

    testWidgets('renders one ArrowWidget per arrow when playing',
        (tester) async {
      // Arrange
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));

      // Act
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      await tester.pump();

      // Assert
      expect(find.byType(ArrowWidget), findsNWidgets(2));
    });

    testWidgets('tapping an arrow removes it from the board', (tester) async {
      // Arrange
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await container
          .read(gameControllerProvider.notifier)
          .loadLevel(LevelId('level-1'));
      await tester.pump();

      // Act
      await tester.tap(
        find.byKey(const ValueKey('a1')),
        warnIfMissed: false,
      );
      await tester.pump();

      // Assert — one arrow consumed, one remains
      expect(find.byType(ArrowWidget), findsOneWidget);
    });
  });
}
