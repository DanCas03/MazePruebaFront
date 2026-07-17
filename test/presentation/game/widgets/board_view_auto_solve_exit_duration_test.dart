import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/exiting_arrow_widget.dart';

import '../../../support/arrow_fixtures.dart';

// #102 — durante la demo del auto-solver, el tablero debe reproducir la
// animación de salida con la duración COMPRIMIDA que trae el estado
// (`autoSolveExitDuration`), no la fija de 360 ms del gameplay normal.

ArrowBoard _board() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('arrow-0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
      ],
      space: RectSpace(4, 4),
    );

Future<void> _pump(WidgetTester tester, GamePlaying state) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400,
        child: BoardView(state: state, onTapArrow: (_) {}),
      ),
    ),
  ));
}

ExitingArrowWidget _exitingWidget(WidgetTester tester) =>
    tester.widget<ExitingArrowWidget>(find.byType(ExitingArrowWidget));

void main() {
  testWidgets(
      'passes the compressed autoSolveExitDuration through to ExitingArrowWidget',
      (tester) async {
    // Arrange — una demo del auto-solver en curso, con el piso comprimido a
    // 120 ms (tablero grande, ver AutoSolvePacing.exitDurationFor).
    final board = _board();
    final exiting = board.arrowById(const ArrowId('arrow-0'));
    await _pump(
      tester,
      GamePlaying(
        board: board.removeArrow(const ArrowId('arrow-0')),
        moves: const MoveCount(0),
        hintPlaying: true,
        exitingArrow: exiting,
        exitNonce: 1,
        autoSolveExitDuration: const Duration(milliseconds: 120),
      ),
    );

    // Assert
    expect(_exitingWidget(tester).duration, const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'falls back to the standard 360ms gameplay duration when autoSolveExitDuration is null',
      (tester) async {
    // Arrange — una salida de gameplay normal (fuera de la demo): sin campo.
    final board = _board();
    final exiting = board.arrowById(const ArrowId('arrow-0'));
    await _pump(
      tester,
      GamePlaying(
        board: board.removeArrow(const ArrowId('arrow-0')),
        moves: const MoveCount(1),
        exitingArrow: exiting,
        exitNonce: 1,
      ),
    );

    // Assert
    expect(_exitingWidget(tester).duration, const Duration(milliseconds: 360));
    await tester.pumpAndSettle();
  });
}
