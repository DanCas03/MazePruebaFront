import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';

Arrow _arrow() => Arrow(
      id: const ArrowId('a1'),
      tail: Position(row: 0, col: 0),
      direction: Direction.right,
      length: ArrowLength(2),
    );

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SizedBox(width: 144, height: 144, child: child)),
    );

void main() {
  group('ArrowWidget', () {
    testWidgets('paints the arrow via ArrowPainter', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _host(ArrowWidget(arrow: _arrow(), cellSize: 72, onTap: () {})),
      );

      // Act
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(ArrowWidget),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter as ArrowPainter;

      // Assert
      expect(painter.arrow, _arrow());
      expect(painter.cellSize, 72);
      expect(painter.isHighlighted, isFalse);
    });

    testWidgets('forwards isHighlighted to the painter', (tester) async {
      // Arrange
      await tester.pumpWidget(
        _host(ArrowWidget(
          arrow: _arrow(),
          cellSize: 72,
          isHighlighted: true,
          onTap: () {},
        )),
      );

      // Act
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(ArrowWidget),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter as ArrowPainter;

      // Assert
      expect(painter.isHighlighted, isTrue);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      // Arrange
      var tapped = false;
      await tester.pumpWidget(
        _host(ArrowWidget(
          arrow: _arrow(),
          cellSize: 72,
          onTap: () => tapped = true,
        )),
      );

      // Act
      await tester.tap(find.byType(ArrowWidget));

      // Assert
      expect(tapped, isTrue);
    });
  });
}
