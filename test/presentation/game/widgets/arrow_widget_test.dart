import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

Arrow _arrow() => Arrow.straight(
      id: const ArrowId('arrow-0'),
      tail: Position(row: 0, col: 0),
      direction: Direction.right,
      length: 2,
    );

void main() {
  group('ArrowWidget', () {
    // Smoke: render-only widget monta sin error. ArrowWidget usa IgnorePointer
    // (no captura toques); la gestión de toques vive en BoardWidget.
    testWidgets('renderiza sin error con isBlocked false', (tester) async {
      // Arrange
      final arrow = _arrow();

      // Act
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: ArrowWidget(
              arrow: arrow,
              minCol: 0,
              minRow: 0,
              cell: 50,
              color: const Color(0xFF46B98C),
              isBlocked: false,
              blockedNonce: 0,
            ),
          ),
        ),
      ));

      // Assert
      expect(find.byType(ArrowWidget), findsOneWidget);
    });

    // Shake trigger: cuando blockedNonce cambia con isBlocked=true, didUpdateWidget
    // dispara el shake sin lanzar.
    testWidgets('actualizar blockedNonce con isBlocked true no lanza', (tester) async {
      // Arrange
      final arrow = _arrow();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: ArrowWidget(
              arrow: arrow,
              minCol: 0,
              minRow: 0,
              cell: 50,
              color: const Color(0xFF46B98C),
              isBlocked: false,
              blockedNonce: 0,
            ),
          ),
        ),
      ));

      // Act — cambia el nonce para disparar el shake
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 100,
            child: ArrowWidget(
              arrow: arrow,
              minCol: 0,
              minRow: 0,
              cell: 50,
              color: const Color(0xFF46B98C),
              isBlocked: true,
              blockedNonce: 1,
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 160));

      // Assert — no excepción durante la animación
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });
  });
}
