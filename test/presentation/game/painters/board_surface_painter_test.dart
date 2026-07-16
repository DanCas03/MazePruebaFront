import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/game_core/space/board_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';

import '../../../support/holed_rect_space.dart';

const _surface = Color(0xFF223344);
const _grid = Color(0x1A99AABB);

BoardSurfacePainter _painter(BoardSpace space, {double cell = 10, Rect? visibleRect}) =>
    BoardSurfacePainter(
      space: space,
      cell: cell,
      surfaceColor: _surface,
      gridColor: _grid,
      visibleRect: visibleRect,
    );

/// Monta el painter en un CustomPaint del tamaño exacto del tablero y
/// devuelve su RenderObject para los matchers de canvas (`paints`).
Future<RenderObject> _pump(
  WidgetTester tester,
  BoardSurfacePainter painter, {
  required double width,
  required double height,
}) async {
  await tester.pumpWidget(Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: painter),
    ),
  ));
  return tester.renderObject(find.byType(CustomPaint));
}

void main() {
  group('caja llena (RectSpace) — regresión píxel del render previo a #87', () {
    testWidgets('pinta UN panel redondeado + líneas de rejilla completas',
        (tester) async {
      // Arrange — 4×4, cell 25 → tablero 100×100, radio 25*0.35 = 8.75
      final render = await _pump(tester, _painter(RectSpace(4, 4), cell: 25),
          width: 100, height: 100);

      // Assert — panel único redondeado, sin rellenos por celda
      expect(
        render,
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 0, 100, 100),
              const Radius.circular(25 * 0.35),
            ),
          ),
      );
      // (cols-1) + (rows-1) = 3 + 3 líneas interiores
      expect(render, paintsExactlyCountTimes(#drawLine, 6));
      expect(render, isNot(paints..rect()));
    });
  });

  group('espacio enmascarado (HoledRectSpace) — solo celdas existentes', () {
    // 3×3 con agujero en (1,1), cell 10 → tablero 30×30.
    // OJO: HoledRectSpace NO resta el agujero de allCells/cellCount (doble de
    // certificación), el painter debe discriminar por `contains`, no por conteo.
    final holed = HoledRectSpace(3, 3, holes: {Position(row: 1, col: 1)});

    testWidgets('rellena las 8 celdas existentes y NO el agujero', (tester) async {
      // Arrange / Act
      final render =
          await _pump(tester, _painter(holed), width: 30, height: 30);

      // Assert
      expect(render, paintsExactlyCountTimes(#drawRect, 8));
      expect(render, paints..rect(rect: const Rect.fromLTWH(0, 0, 10, 10)));
      expect(render,
          isNot(paints..rect(rect: const Rect.fromLTWH(10, 10, 10, 10))));
      expect(render, isNot(paints..rrect()));
    });

    testWidgets('la rejilla solo existe entre dos celdas existentes', (tester) async {
      // Arrange / Act
      final render =
          await _pump(tester, _painter(holed), width: 30, height: 30);

      // Assert — 12 aristas interiores del 3×3 menos las 4 que tocan el agujero
      expect(render, paintsExactlyCountTimes(#drawLine, 8));
    });

    testWidgets('culling: con encuadre de la primera columna solo pinta esas celdas',
        (tester) async {
      // Arrange — encuadre que cubre solo la columna 0 (x ∈ [0,10])
      final render = await _pump(
        tester,
        _painter(holed, visibleRect: const Rect.fromLTWH(0, 0, 10, 30)),
        width: 30,
        height: 30,
      );

      // Assert — (0,0), (1,0), (2,0): 3 rellenos
      expect(render, paintsExactlyCountTimes(#drawRect, 3));
    });
  });

  group('shouldRepaint', () {
    test('true si cambia el espacio; false si es equivalente por valor', () {
      // Arrange
      final a = _painter(RectSpace(3, 3));
      final b = _painter(RectSpace(3, 3));
      final c = _painter(HoledRectSpace(3, 3, holes: {Position(row: 0, col: 0)}));

      // Act / Assert — BoardSpace es Equatable: igualdad por valor
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}
