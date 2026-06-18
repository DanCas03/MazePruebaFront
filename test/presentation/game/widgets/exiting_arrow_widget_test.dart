import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/exiting_arrow_widget.dart';

Arrow _arrow(Direction dir) => Arrow(
      id: const ArrowId('a1'),
      tail: Position(row: 1, col: 1),
      direction: dir,
      length: ArrowLength(2),
    );

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SizedBox(width: 288, height: 288, child: child)),
    );

void main() {
  group('ExitingArrowWidget', () {
    testWidgets('uses SlideTransition and FadeTransition', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _host(ExitingArrowWidget(
          arrow: _arrow(Direction.right),
          cellSize: 72,
          onComplete: () {},
        )),
      );

      // Act
      // (render only — do not settle, the animation drives onComplete)

      // Assert — scope to the widget's own subtree (the MaterialApp page
      // route also uses transitions, so a global finder would over-match).
      expect(
        find.descendant(
          of: find.byType(ExitingArrowWidget),
          matching: find.byType(SlideTransition),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ExitingArrowWidget),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );

      // Drain the pending animation so the test does not leak a timer.
      await tester.pumpAndSettle();
    });

    testWidgets('invokes onComplete after the animation finishes',
        (tester) async {
      // Arrange
      var done = false;
      await tester.pumpWidget(
        _host(ExitingArrowWidget(
          arrow: _arrow(Direction.up),
          cellSize: 72,
          onComplete: () => done = true,
        )),
      );

      // Act
      expect(done, isFalse); // not yet — animation in flight
      await tester.pumpAndSettle();

      // Assert
      expect(done, isTrue);
    });

    testWidgets('disposes its controller without leaking', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _host(ExitingArrowWidget(
          arrow: _arrow(Direction.down),
          cellSize: 72,
          onComplete: () {},
        )),
      );

      // Act — remove the widget mid-animation
      await tester.pumpWidget(_host(const SizedBox.shrink()));

      // Assert — no exception (a leaked AnimationController would throw)
      expect(tester.takeException(), isNull);
    });
  });
}
