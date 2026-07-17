import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import '../../../support/arrow_fixtures.dart';

/// Celdas de la silueta temática (#118) dentro de la caja 4×4: la FIGURA es el
/// tablero. Incluye (1,1), celda de la figura sin flecha —superficie jugable—,
/// y deja fuera 11 de las 16 celdas de la caja: ahí no hay tablero.
Set<Position> _silhouette() => {
      Position(row: 0, col: 0),
      Position(row: 0, col: 1),
      Position(row: 1, col: 1),
      Position(row: 2, col: 2),
      Position(row: 2, col: 3),
    };

/// Tablero temático tal y como lo MONTA el controlador (#118): las mismas dos
/// flechas del wire sobre el MaskedSpace de su silueta.
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
      space: MaskedSpace(4, 4, activeCells: _silhouette()),
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
  testWidgets('un tablero temático pinta SOLO las celdas de su silueta',
      (tester) async {
    // Arrange / Act
    await _pump(tester);

    // Assert — el painter recibe el espacio enmascarado del board y toma su
    // camino celda a celda: un `drawRect` por celda ACTIVA (5), ninguno para
    // las 11 celdas de la caja que quedan fuera de la figura. Sin panel
    // rectangular de fondo: fuera de la silueta no se pinta tablero.
    final paint = tester.widget<CustomPaint>(_surfacePaint());
    expect((paint.painter! as BoardSurfacePainter).space,
        MaskedSpace(4, 4, activeCells: _silhouette()));
    expect(tester.renderObject(_surfacePaint()),
        paintsExactlyCountTimes(#drawRect, 5));
  });

  testWidgets('un toque fuera de la silueta no enruta ninguna flecha',
      (tester) async {
    // Arrange
    final taps = await _pump(tester);

    // Act — (3,3) está dentro de la caja 4×4 pero FUERA de la figura: ahí no
    // hay tablero, así que el toque muere en `space.contains`.
    await tester.tapAt(const Offset(350, 350));
    await tester.pump();

    // Assert
    expect(taps, isEmpty);
  });

  testWidgets('un toque sobre una flecha de la silueta sigue enrutando',
      (tester) async {
    // Arrange
    final taps = await _pump(tester);

    // Act — (0,0), cuerpo de arrow-0, celda activa de la figura.
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    // Assert — enmascarar el tablero no rompe la mecánica dentro de la figura.
    expect(taps, [const ArrowId('arrow-0')]);
  });
}
