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

  testWidgets(
      'bajo zoom de lectura, el culling hex usa la caja de píxeles real '
      '(no la proyección rect, que la cullearía de más)', (t) async {
    // front#126 (fix final-review): antes del fix, onCamera comparaba con la
    // proyección RECTANGULAR (minCol-frame.minCol)*cell, que no es el espacio
    // de píxeles de un hex. A "fit" la cámara cubre todo el tablero y el bug
    // queda invisible (por eso el mount test de arriba no lo detecta); hace
    // falta zoom real para que la cámara sea más chica que el tablero.
    //
    // La celda 'edge' (fila 0, columnas 16-17 con R=10) está calculada para
    // que, tras un doble-tap centrado en el tablero (zoom de lectura 2.6x,
    // BoardViewport#66), su AABB de píxeles REAL (_pixelBox, vía centerOf)
    // siga solapando la cámara, pero la proyección RECT antigua
    // ((col)*cellSize, (row)*cellSize) caiga fuera de ella — un caso real de
    // sobre-culling que el fix corrige. Verificado numéricamente: con R=10,
    // constraints 400x600 y tap en el centro (row:10,col:10), la cámara
    // inflada queda en x∈[79.8,320.2] y∈[68.6,386.0]; el AABB real de la
    // celda 'edge' (≈x∈[290.8,352.9] y∈[54.1,108.3]) solapa esa cámara,
    // mientras que su proyección rect buggy (x∈[346.4,389.7] y∈[0,21.7]) no.
    const r = 10;
    final board = ArrowBoard(
      arrows: [
        // Bajo la cámara, tanto en la proyección rect como en píxeles reales
        // (sanity: el culling normal sigue construyéndola).
        Arrow(
          id: const ArrowId('near'),
          headDirection: Direction.downRight,
          cells: [Position(row: r, col: r), Position(row: r, col: r + 1)],
        ),
        // Caso discriminante: visible con el AABB real, culleada de más con
        // la proyección rect (ver cálculo arriba).
        Arrow(
          id: const ArrowId('edge'),
          headDirection: Direction.downRight,
          cells: [Position(row: 0, col: 2 * r - 4), Position(row: 0, col: 2 * r - 3)],
        ),
      ],
      space: const HexSpace(r),
    );
    final state = GamePlaying(board: board, moves: const MoveCount(0));

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: BoardView(state: state, onTapArrow: (_) {}),
          ),
        ),
      ),
    ));

    // A "fit" (zoom identidad) la cámara cubre todo el tablero: ambas están
    // construidas.
    expect(find.byKey(const ValueKey('near')), findsOneWidget);
    expect(find.byKey(const ValueKey('edge')), findsOneWidget);

    // Doble-tap en el centro geométrico del tablero (celda axial q=0,r=0, el
    // punto bajo el que queda fijo el zoom de lectura, BoardViewport#66) ->
    // acerca a escala 2.6 centrado ahí.
    final geo = HexGeometry(
      const HexSpace(r),
      const BoxConstraints(maxWidth: 400, maxHeight: 600),
    );
    final tl = t.getTopLeft(find.byType(BoardView));
    final letterbox = Offset(
      (400 - geo.size.width) / 2,
      (600 - geo.size.height) / 2,
    );
    final centerHex = geo.centerOf(Position(row: r, col: r));
    final tapPoint = tl + letterbox + centerHex;
    await t.tapAt(tapPoint);
    await t.tapAt(tapPoint);
    await t.pumpAndSettle();

    // Tras el zoom: 'near' sigue construida (sanity), y 'edge' TAMBIÉN sigue
    // construida porque su AABB de píxeles real solapa la cámara — con el
    // bug de la proyección rect, 'edge' se cullearía incorrectamente
    // (findsNothing) pese a estar dentro del encuadre visible.
    expect(find.byKey(const ValueKey('near')), findsOneWidget);
    expect(find.byKey(const ValueKey('edge')), findsOneWidget);
  });
}
