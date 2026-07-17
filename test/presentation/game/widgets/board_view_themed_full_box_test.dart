import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import '../../../support/arrow_fixtures.dart';

/// Nivel temático 4×4 (front#114): el tablero se monta ENMASCARADO a la figura
/// (silueta) y no se pinta superficie alguna — ni panel ni rejilla —: la figura
/// la dibujan solo las flechas; una celda de figura sin flecha no muestra nada.
///   arrow-0: (0,0)-(0,1)   arrow-2: (2,2)-(2,3)
///   figura: las 4 celdas de flecha + (1,1),(1,2) sin flecha.
final Map<String, List<Position>> _silhouette = {
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

List<Arrow> _arrows() => [
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
    ];

ArrowBoard _themedBoard() => ArrowBoard(
      arrows: _arrows(),
      space: MaskedSpace(4, 4, activeCells: {
        for (final cells in _silhouette.values) ...cells,
      }),
    );

ArrowBoard _campaignBoard() => ArrowBoard(
      arrows: _arrows(),
      space: RectSpace(4, 4),
    );

Future<List<ArrowId>> _pump(WidgetTester tester, GamePlaying state) async {
  final taps = <ArrowId>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 400, // caja 4×4 ⇒ cell = 100
        child: BoardView(
          state: state,
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
      'a themed board (silhouette present) paints NO surface — only arrows',
      (tester) async {
    // Arrange / Act
    await _pump(
      tester,
      GamePlaying(
        board: _themedBoard(),
        moves: const MoveCount(0),
        palette: const {'body': '#ff0000', 'tail': '#00ff00'},
        silhouette: _silhouette,
      ),
    );

    // Assert — front#114: sin panel ni rejilla (el BoardSurfacePainter no se
    // monta); la figura la dibujan únicamente las flechas.
    expect(_surfacePaint(), findsNothing);
    expect(find.byType(ArrowWidget), findsNWidgets(2));
  });

  testWidgets('a campaign board (no silhouette) still paints its surface panel',
      (tester) async {
    // Arrange / Act
    await _pump(
      tester,
      GamePlaying(board: _campaignBoard(), moves: const MoveCount(0)),
    );

    // Assert — la campaña conserva el panel de superficie de siempre.
    expect(_surfacePaint(), findsOneWidget);
  });

  testWidgets('arrow taps keep working on the masked themed board',
      (tester) async {
    // Arrange
    final taps = await _pump(
      tester,
      GamePlaying(
        board: _themedBoard(),
        moves: const MoveCount(0),
        palette: const {'body': '#ff0000', 'tail': '#00ff00'},
        silhouette: _silhouette,
      ),
    );

    // Act — (1,1) es figura SIN flecha: el tap cae en celda existente pero no
    // enruta flecha alguna; (3,0) está FUERA de la máscara: se rechaza.
    await tester.tapAt(const Offset(150, 150));
    await tester.tapAt(const Offset(50, 350));
    await tester.pump();
    expect(taps, isEmpty);

    // (0,0) es la cabeza de arrow-0: la mecánica de las flechas sigue intacta.
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();
    expect(taps, [const ArrowId('arrow-0')]);
  });
}
