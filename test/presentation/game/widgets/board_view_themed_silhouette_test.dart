import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import '../../../support/arrow_fixtures.dart';

/// Nivel temático 4×4 con dos flechas: la silueta derivada por el dominio son
/// SUS 4 celdas, no la caja de 16.
///   arrow-0: (0,0)-(0,1)   arrow-2: (2,2)-(2,3)
ArrowBoard _themedBoard() => ArrowBoard(
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
    ).withSilhouetteSpace();

Future<List<ArrowId>> _pump(WidgetTester tester) async {
  final taps = <ArrowId>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400, // caja 4×4 ⇒ cell = 100
        child: BoardView(
          state: GamePlaying(board: _themedBoard(), moves: const MoveCount(0)),
          onTapArrow: taps.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return taps;
}

Finder _surfacePaint() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is BoardSurfacePainter);

void main() {
  testWidgets('a themed level paints only the figure cells, not the full box',
      (tester) async {
    // Arrange / Act
    await _pump(tester);

    // Assert — se rellenan las 4 celdas de la silueta (no las 16 de la caja).
    expect(tester.renderObject(_surfacePaint()),
        paintsExactlyCountTimes(#drawRect, 4));
  });

  testWidgets('a tap off the figure is rejected; a tap on a figure arrow routes',
      (tester) async {
    // Arrange
    final taps = await _pump(tester);

    // Act — (3,3) queda FUERA de la silueta; (0,0) es la cabeza de arrow-0.
    await tester.tapAt(const Offset(350, 350));
    await tester.pump();
    expect(taps, isEmpty);

    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    // Assert
    expect(taps, [const ArrowId('arrow-0')]);
  });
}
