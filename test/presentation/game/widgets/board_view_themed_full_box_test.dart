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

/// Nivel temático 4×4 cuyas dos flechas dejan celdas interiores SIN ocupar —el
/// caso que producía agujeros a mitad de tablero (front#99). Con la silueta
/// previa (#88) esas celdas quedaban sin pintar; ahora el nivel se monta sobre
/// su caja rectangular completa, así que las 16 celdas son superficie.
///   arrow-0: (0,0)-(0,1)   arrow-2: (2,2)-(2,3)
/// Interiores vacíos como (1,1),(1,2),(2,0) eran agujeros bajo la silueta.
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
    );

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
  testWidgets(
      'a themed board paints the full box (no unpainted mid-board holes)',
      (tester) async {
    // Arrange / Act
    await _pump(tester);

    // Assert — al ser la caja completa, la superficie se pinta por el camino de
    // panel lleno (un único RRect redondeado), NO celda a celda: no queda ni un
    // `drawRect` suelto que delataría agujeros interiores.
    expect(tester.renderObject(_surfacePaint()),
        paintsExactlyCountTimes(#drawRect, 0));
  });

  testWidgets('an interior cell with no arrow is painted surface, not a hole',
      (tester) async {
    // Arrange
    final taps = await _pump(tester);

    // Act — (1,1) NO tiene flecha: antes era un agujero (tap vetado por estar
    // fuera de la silueta); ahora es superficie pintada, así que el tap se
    // acepta sobre la celda pero no enruta ninguna flecha (no hay ninguna allí).
    await tester.tapAt(const Offset(150, 150));
    await tester.pump();
    expect(taps, isEmpty);

    // (0,0) es la cabeza de arrow-0: la mecánica de las flechas sigue intacta.
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(taps, [const ArrowId('arrow-0')]);
  });
}
