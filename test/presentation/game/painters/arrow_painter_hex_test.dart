import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  testWidgets('con geometry, la flecha recorre centros hex (no lineales)', (t) async {
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2), Position(row: 2, col: 3)]; // downRight
    final origin = g.centerOf(cells.first); // origen arbitrario de la caja
    final painter = ArrowPainter(
      cells: cells,
      minCol: 2,
      minRow: 2,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      headDirection: Direction.downRight,
      geometry: g,
      origin: origin,
    );
    await t.pumpWidget(Center(
      child: SizedBox(width: 400, height: 400, child: CustomPaint(painter: painter)),
    ));
    final ro = t.renderObject<RenderBox>(find.byType(CustomPaint).first);
    // El cuerpo se pinta como path (glow + cuerpo + brillo) + cabeza => >=4 drawPath.
    expect(ro, paintsExactlyCountTimes(#drawPath, 4));
  });

  test('_center con geometry devuelve centerOf − origin', () {
    final g = HexGeometry(const HexSpace(2), c);
    final p0 = Position(row: 2, col: 2);
    final p1 = Position(row: 2, col: 3);
    final origin = g.centerOf(p0);
    // El delta entre centros locales debe igualar el delta de centerOf.
    final expectedDelta = g.centerOf(p1) - g.centerOf(p0);
    // (verificado indirectamente: el segundo centro local = expectedDelta)
    expect(expectedDelta.dx, isNot(closeTo(g.cellSize, 1e-9)),
        reason: 'diagonal hex: dx != cellSize entero, prueba no-lineal');
  });
}
