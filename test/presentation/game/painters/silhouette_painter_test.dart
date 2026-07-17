import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/game_core/space/bounding_box.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/silhouette_painter.dart';

const _frame = BoundingBox(minRow: 1, minCol: 1, rows: 3, cols: 3);

SilhouettePainter _painter({
  required Map<String, List<Position>> silhouette,
  required Map<String, String> palette,
  double cell = 10,
  double alpha = 0.30,
}) =>
    SilhouettePainter(
      frame: _frame,
      cell: cell,
      silhouette: silhouette,
      palette: palette,
      alpha: alpha,
    );

/// Monta el painter en un CustomPaint del tamaño exacto del tablero y
/// devuelve su RenderObject para los matchers de canvas (`paints`), siguiendo
/// el mismo patrón que `board_surface_painter_test.dart`.
Future<RenderObject> _pump(
  WidgetTester tester,
  SilhouettePainter painter, {
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
  group('rol con hex válido', () {
    testWidgets('rellena cada celda de la silueta con el color del rol',
        (tester) async {
      // Arrange — un rol con dos celdas, offset por el frame (minRow/minCol=1)
      final render = await _pump(
        tester,
        _painter(
          silhouette: {
            'head': [
              Position(row: 1, col: 1),
              Position(row: 1, col: 2),
            ],
          },
          palette: {'head': '#112233'},
        ),
        width: 30,
        height: 30,
      );

      // Assert — exactamente 2 drawRect, en el offset relativo al frame
      expect(render, paintsExactlyCountTimes(#drawRect, 2));
      expect(
        render,
        paints
          ..rect(
            rect: const Rect.fromLTWH(0, 0, 10, 10),
            color: const Color(0xFF112233).withValues(alpha: 0.30),
          )
          ..rect(
            rect: const Rect.fromLTWH(10, 0, 10, 10),
            color: const Color(0xFF112233).withValues(alpha: 0.30),
          ),
      );
    });
  });

  group('rol ausente de la paleta o con hex inválido', () {
    testWidgets('un rol sin entrada en la paleta no pinta nada', (tester) async {
      // Arrange / Act
      final render = await _pump(
        tester,
        _painter(
          silhouette: {
            'head': [Position(row: 1, col: 1)],
          },
          palette: const {},
        ),
        width: 30,
        height: 30,
      );

      // Assert
      expect(render, isNot(paints..rect()));
    });

    testWidgets('un rol con hex inválido no pinta nada', (tester) async {
      // Arrange / Act
      final render = await _pump(
        tester,
        _painter(
          silhouette: {
            'head': [Position(row: 1, col: 1)],
          },
          palette: {'head': 'not-a-color'},
        ),
        width: 30,
        height: 30,
      );

      // Assert
      expect(render, isNot(paints..rect()));
    });
  });
}
