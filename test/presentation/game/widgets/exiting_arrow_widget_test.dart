import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/exiting_arrow_widget.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

Arrow _arrow(Direction dir) => Arrow.straight(
      id: const ArrowId('arrow-0'),
      tail: Position(row: 1, col: 1),
      direction: dir,
      length: 2,
    );

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 288, height: 288, child: child),
      ),
    );

void main() {
  group('ExitingArrowWidget', () {
    // Smoke: el overlay cosmético monta sin lanzar excepción.
    // ExitingArrowWidget se auto-desmonta al terminar la animación (300 ms).
    // Debe ir keyed por exitNonce en BoardWidget para que cada salida re-anime.
    testWidgets('monta y renderiza sin error', (tester) async {
      // Arrange + Act
      await tester.pumpWidget(_host(ExitingArrowWidget(
        key: const ValueKey('exiting-1'),
        arrow: _arrow(Direction.right),
        minCol: 1,
        minRow: 1,
        cell: 72,
        color: const Color(0xFF46B98C),
        travel: 200,
        nonce: 1,
      )));

      // Assert — el widget está presente antes de que la animación termine
      expect(find.byType(ExitingArrowWidget), findsOneWidget);

      // Drenar timers pendientes para no filtrar animación.
      await tester.pumpAndSettle();
    });

    // Slide+fade: la animación usa Transform + Opacity (no SlideTransition/
    // FadeTransition — la nueva impl es AnimatedBuilder con Transform.translate
    // y Opacity inline), así que solo verificamos que NO lanza y se puede
    // avanzar a mitad de animación.
    testWidgets('a mitad de animación no lanza excepción', (tester) async {
      // Arrange
      await tester.pumpWidget(_host(ExitingArrowWidget(
        key: const ValueKey('exiting-2'),
        arrow: _arrow(Direction.up),
        minCol: 1,
        minRow: 1,
        cell: 72,
        color: const Color(0xFF46B98C),
        travel: 200,
        nonce: 2,
      )));

      // Act — avanzar a la mitad de la animación de 300 ms
      await tester.pump(const Duration(milliseconds: 150));

      // Assert
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    // Dispose: desmontar antes de que termine no filtra AnimationController.
    testWidgets('dispose a mitad de animación no filtra controlador', (tester) async {
      // Arrange
      await tester.pumpWidget(_host(ExitingArrowWidget(
        key: const ValueKey('exiting-3'),
        arrow: _arrow(Direction.down),
        minCol: 1,
        minRow: 1,
        cell: 72,
        color: const Color(0xFF46B98C),
        travel: 200,
        nonce: 3,
      )));

      // Act — desmontar el widget a mitad de la animación
      await tester.pumpWidget(_host(const SizedBox.shrink()));

      // Assert — no hay excepción por controlador no dispuesto
      expect(tester.takeException(), isNull);
    });

    // Keying: dos instancias con distinto nonce son widgets distintos.
    testWidgets('key por nonce distingue dos instancias', (tester) async {
      // Arrange
      final w1 = ExitingArrowWidget(
        key: const ValueKey('exiting-10'),
        arrow: _arrow(Direction.left),
        minCol: 1,
        minRow: 1,
        cell: 72,
        color: const Color(0xFF46B98C),
        travel: 200,
        nonce: 10,
      );
      final w2 = ExitingArrowWidget(
        key: const ValueKey('exiting-11'),
        arrow: _arrow(Direction.left),
        minCol: 1,
        minRow: 1,
        cell: 72,
        color: const Color(0xFF46B98C),
        travel: 200,
        nonce: 11,
      );

      // Act
      await tester.pumpWidget(_host(Stack(children: [w1, w2])));

      // Assert — ambas instancias están presentes
      expect(find.byType(ExitingArrowWidget), findsNWidgets(2));
      await tester.pumpAndSettle();
    });
  });
}
