import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/theme/app_colors.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';

Arrow _arrow({
  required Direction direction,
  int length = 3,
  int row = 2,
  int col = 1,
}) {
  return Arrow(
    id: ArrowId('a1'),
    tail: Position(row: row, col: col),
    direction: direction,
    length: ArrowLength(length),
  );
}

void main() {
  const cellSize = 40.0;

  group('ArrowPainter.bodyColorFor', () {
    test('maps each direction to its palette color', () {
      // Arrange + Act + Assert
      expect(ArrowPainter.bodyColorFor(Direction.up), AppColors.arrowUp);
      expect(ArrowPainter.bodyColorFor(Direction.down), AppColors.arrowDown);
      expect(ArrowPainter.bodyColorFor(Direction.left), AppColors.arrowLeft);
      expect(ArrowPainter.bodyColorFor(Direction.right), AppColors.arrowRight);
    });
  });

  group('ArrowPainter.shouldRepaint', () {
    test('returns false when arrow and highlight are unchanged', () {
      // Arrange
      final arrow = _arrow(direction: Direction.right);
      final p1 = ArrowPainter(arrow: arrow, cellSize: cellSize);
      final p2 = ArrowPainter(arrow: arrow, cellSize: cellSize);

      // Act
      final repaint = p1.shouldRepaint(p2);

      // Assert
      expect(repaint, isFalse);
    });

    test('returns true when the arrow changes', () {
      // Arrange
      final p1 =
          ArrowPainter(arrow: _arrow(direction: Direction.right), cellSize: cellSize);
      final p2 =
          ArrowPainter(arrow: _arrow(direction: Direction.left), cellSize: cellSize);

      // Act + Assert
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('returns true when the highlight flag changes', () {
      // Arrange
      final arrow = _arrow(direction: Direction.up);
      final p1 = ArrowPainter(arrow: arrow, cellSize: cellSize);
      final p2 =
          ArrowPainter(arrow: arrow, cellSize: cellSize, isHighlighted: true);

      // Act + Assert
      expect(p1.shouldRepaint(p2), isTrue);
    });
  });

  group('ArrowPainter.paint', () {
    for (final direction in Direction.values) {
      test('paints a $direction arrow without throwing', () {
        // Arrange
        final painter = ArrowPainter(
          arrow: _arrow(direction: direction, row: 4, col: 4),
          cellSize: cellSize,
        );
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        // Act + Assert
        expect(
          () => painter.paint(canvas, const Size(400, 400)),
          returnsNormally,
        );
      });
    }

    test('paints a highlighted arrow (glow layer) without throwing', () {
      // Arrange
      final painter = ArrowPainter(
        arrow: _arrow(direction: Direction.down, row: 2, col: 5),
        cellSize: cellSize,
        isHighlighted: true,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(400, 400)),
        returnsNormally,
      );
    });

    test('paints a single-cell arrow without throwing', () {
      // Arrange
      final painter = ArrowPainter(
        arrow: _arrow(direction: Direction.right, length: 1, row: 0, col: 0),
        cellSize: cellSize,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(400, 400)),
        returnsNormally,
      );
    });
  });
}
