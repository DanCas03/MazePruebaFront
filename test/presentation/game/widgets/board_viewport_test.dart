import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/presentation/game/widgets/board_viewport.dart';

/// Monta un [BoardViewport] de 300×300 (tablero = viewport ⇒ "fit" a escala 1)
/// y devuelve el último rectángulo visible que el builder recibió.
Future<Rect?> _pumpViewport(WidgetTester tester) async {
  Rect? lastVisible;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: BoardViewport(
              viewportSize: const Size(300, 300),
              boardSize: const Size(300, 300),
              builder: (visibleRect) {
                lastVisible = visibleRect;
                // Opaco: como el tablero real, para que el Listener del viewport
                // reciba los eventos de puntero sobre toda su área.
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return lastVisible;
}

double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value
    .getMaxScaleOnAxis();

void main() {
  testWidgets('el builder recibe el rectángulo visible del tablero en fit',
      (tester) async {
    final visible = await _pumpViewport(tester);

    // A escala 1 (fit) el encuadre cubre todo el tablero.
    expect(visible, isNotNull);
    expect(visible!.left, closeTo(0, 0.5));
    expect(visible.top, closeTo(0, 0.5));
    expect(visible.right, closeTo(300, 0.5));
    expect(visible.bottom, closeTo(300, 0.5));
  });

  testWidgets('doble-tap acerca a zoom de lectura y otro doble-tap vuelve a fit',
      (tester) async {
    await _pumpViewport(tester);
    expect(_scale(tester), closeTo(1.0, 0.01));

    // Doble toque en el centro real del viewport → zoom de lectura.
    final center = tester.getCenter(find.byType(BoardViewport));
    await tester.tapAt(center);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1.5));

    // Otro doble toque → reset a fit.
    await tester.tapAt(center);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1.0, 0.05));
  });

  testWidgets('un toque simple no dispara zoom (queda en fit)', (tester) async {
    await _pumpViewport(tester);

    await tester.tapAt(tester.getCenter(find.byType(BoardViewport)));
    await tester.pumpAndSettle();

    expect(_scale(tester), closeTo(1.0, 0.01));
  });
}
