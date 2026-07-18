import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/hex_board_surface_painter.dart';

const _surface = Color(0xFF223344);
const _grid = Color(0x11FFFFFF);
const _c = BoxConstraints(maxWidth: 800, maxHeight: 800);

HexBoardSurfacePainter _painter(HexSpace space, HexGeometry geometry) =>
    HexBoardSurfacePainter(
      space: space,
      geometry: geometry,
      surfaceColor: _surface,
      gridColor: _grid,
    );

/// Monta el painter en un CustomPaint del tamaño exacto del tablero y
/// devuelve su RenderObject para los matchers de canvas (`paints`). Mismo
/// patrón que board_surface_painter_test.dart (topLeft Align + único
/// CustomPaint, sin `.first`) para no atrapar el CustomPaint del framework.
Future<RenderObject> _pump(
  WidgetTester tester,
  HexBoardSurfacePainter painter,
  HexGeometry geometry,
) async {
  await tester.pumpWidget(Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: geometry.size.width,
      height: geometry.size.height,
      child: CustomPaint(painter: painter),
    ),
  ));
  return tester.renderObject(find.byType(CustomPaint));
}

void main() {
  testWidgets('R=1 completo: 7 hexágonos + 12 aristas interiores',
      (tester) async {
    // Arrange
    final space = const HexSpace(1);
    final geometry = HexGeometry(space, _c);

    // Act
    final render = await _pump(tester, _painter(space, geometry), geometry);

    // Assert
    expect(render, paintsExactlyCountTimes(#drawPath, 7));
    expect(render, paintsExactlyCountTimes(#drawLine, 12));
  });

  testWidgets('R=2 completo: 19 hexágonos', (tester) async {
    // Arrange
    final space = const HexSpace(2);
    final geometry = HexGeometry(space, _c);

    // Act
    final render = await _pump(tester, _painter(space, geometry), geometry);

    // Assert
    expect(render, paintsExactlyCountTimes(#drawPath, 19));
  });

  testWidgets('R=1 con centro hueco: 6 hexágonos + 6 aristas del anillo',
      (tester) async {
    // Arrange
    final active = const HexSpace(1).allCells.toSet()
      ..remove(Position(row: 1, col: 1));
    final space = HexMaskedSpace(1, activeCells: active);
    final geometry = HexGeometry(space, _c);
    final painter = HexBoardSurfacePainter(
      space: space,
      geometry: geometry,
      surfaceColor: _surface,
      gridColor: _grid,
    );

    // Act
    final render = await _pump(tester, painter, geometry);

    // Assert
    expect(render, paintsExactlyCountTimes(#drawPath, 6));
    expect(render, paintsExactlyCountTimes(#drawLine, 6));
  });

  group('shouldRepaint', () {
    test('true si cambia el espacio; false si es equivalente por valor', () {
      // Arrange
      final geometryA = HexGeometry(const HexSpace(1), _c);
      final a = _painter(const HexSpace(1), geometryA);
      final b = _painter(const HexSpace(1), geometryA);
      final geometryC = HexGeometry(const HexSpace(2), _c);
      final c = _painter(const HexSpace(2), geometryC);

      // Act / Assert — HexSpace es Equatable: igualdad por valor
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}
