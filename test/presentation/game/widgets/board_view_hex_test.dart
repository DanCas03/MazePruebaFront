import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

GamePlaying _hexPlaying() {
  final board = ArrowBoard(
    arrows: [
      Arrow(
        id: const ArrowId('h0'),
        headDirection: Direction.downRight,
        cells: [Position(row: 2, col: 2), Position(row: 2, col: 3)],
      ),
    ],
    space: const HexSpace(2),
  );
  return GamePlaying(board: board, moves: const MoveCount(0));
}

void main() {
  testWidgets('monta un nivel hex y el tap sobre la celda cabeza selecciona h0',
      (t) async {
    ArrowId? tapped;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: BoardView(
              state: _hexPlaying(),
              onTapArrow: (id) => tapped = id,
            ),
          ),
        ),
      ),
    ));

    // El árbol hex se monta sin excepción.
    expect(find.byType(BoardView), findsOneWidget);

    // Aserción positiva DETERMINISTA que distingue hex de rect. Reconstruyo la
    // MISMA HexGeometry que el widget (SizedBox 400x600 => constraints tight) y
    // proyecto el centro de la celda cabeza (row:2,col:3). El BoardViewport
    // centra el tablero (400x433) dentro del viewport (letterbox vertical), así
    // que traslado el centro de BoardView por el offset de letterbox para pasar
    // a coordenadas de tablero. Bajo geometría hex ese punto cae en la celda
    // (2,3) -> h0; bajo la geometría rect antigua (tablero 400x400, celda 80)
    // el mismo punto de pantalla cae en (3,3) -> sin flecha -> null. El test
    // por tanto FALLA con el render rect y solo pasa con el montaje hex.
    final geo = HexGeometry(
      const HexSpace(2),
      const BoxConstraints(maxWidth: 400, maxHeight: 600),
    );
    final tl = t.getTopLeft(find.byType(BoardView));
    final letterbox = Offset(0, (600 - geo.size.height) / 2);
    final headCenter = geo.centerOf(Position(row: 2, col: 3));
    await t.tapAt(tl + letterbox + headCenter);
    await t.pump();
    expect(tapped, const ArrowId('h0'));
  });

  testWidgets('un tap fuera del hexágono (esquina) no selecciona nada',
      (t) async {
    ArrowId? tapped;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: BoardView(
              state: _hexPlaying(),
              onTapArrow: (id) => tapped = id,
            ),
          ),
        ),
      ),
    ));
    final tl = t.getTopLeft(find.byType(BoardView));
    await t.tapAt(tl + const Offset(2, 2)); // esquina de la caja: fuera del hex
    await t.pump();
    expect(tapped, isNull);
  });
}
