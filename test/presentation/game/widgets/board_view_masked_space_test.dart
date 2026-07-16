import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import '../../../support/arrow_fixtures.dart';
import '../../../support/holed_rect_space.dart';

/// Tablero 3×3 con agujero en (1,1) y dos flechas:
///   arrow-top:  celdas (0,0)-(0,1) — sobre celdas existentes
///   arrow-hole: celda (1,1) — PATOLÓGICA, montada sobre el agujero a
///   propósito: si el toque llegara a arrowAt, la encontraría. Prueba que el
///   rechazo ocurre por `space.contains` ANTES de resolver la flecha.
ArrowBoard _maskedBoard() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('arrow-top'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        straightArrow(
          id: const ArrowId('arrow-hole'),
          tail: Position(row: 1, col: 1),
          direction: Direction.right,
          length: 1,
        ),
      ],
      space: HoledRectSpace(3, 3, holes: {Position(row: 1, col: 1)}),
    );

/// Monta un BoardView PURO (sin providers) en 300×300 → cell = 100.
/// Devuelve la lista donde se acumulan los taps enrutados.
Future<List<ArrowId>> _pumpMasked(WidgetTester tester) async {
  final taps = <ArrowId>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 300,
        child: BoardView(
          state: GamePlaying(board: _maskedBoard(), moves: const MoveCount(0)),
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
  testWidgets('la superficie se pinta a través del ESPACIO del board',
      (tester) async {
    // Arrange / Act
    await _pumpMasked(tester);

    // Assert — el painter recibe el space del board (no dims sueltas) y, a
    // nivel de widget, solo rellena las 8 celdas existentes (cell = 100).
    final paint = tester.widget<CustomPaint>(_surfacePaint());
    expect((paint.painter! as BoardSurfacePainter).space,
        HoledRectSpace(3, 3, holes: {Position(row: 1, col: 1)}));
    expect(tester.renderObject(_surfacePaint()),
        paintsExactlyCountTimes(#drawRect, 8));
  });

  testWidgets('un toque sobre una celda que NO existe se rechaza aunque haya flecha',
      (tester) async {
    // Arrange
    final taps = await _pumpMasked(tester);

    // Act — centro de la celda (1,1), el agujero, donde vive arrow-hole
    await tester.tapAt(const Offset(150, 150));
    await tester.pump();

    // Assert — space.contains veta el toque antes de arrowAt
    expect(taps, isEmpty);
  });

  testWidgets('un toque sobre una celda existente enruta a su flecha',
      (tester) async {
    // Arrange
    final taps = await _pumpMasked(tester);

    // Act — centro de la celda (0,0), cuerpo de arrow-top
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    // Assert
    expect(taps, [const ArrowId('arrow-top')]);
  });
}
