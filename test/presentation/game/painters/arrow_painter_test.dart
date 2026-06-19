import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

// Construye un ArrowPainter con la nueva firma (polilínea de celdas, sin Arrow).
ArrowPainter _painter(Color color) => ArrowPainter(
      cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
      minCol: 0,
      minRow: 0,
      cell: 40,
      color: color,
    );

void main() {
  // Smoke: el painter pinta una flecha recta sin lanzar excepción.
  test('pinta una flecha recta sin lanzar', () {
    // Arrange
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    // Act + Assert
    expect(
      () => _painter(const Color(0xFF46B98C)).paint(canvas, const Size(80, 40)),
      returnsNormally,
    );
  });

  // shouldRepaint: true cuando el color cambia.
  test('shouldRepaint es true al cambiar el color', () {
    // Arrange
    final a = _painter(const Color(0xFF46B98C));
    final b = _painter(const Color(0xFFD56C8E));

    // Act + Assert
    expect(b.shouldRepaint(a), isTrue);
  });

  // shouldRepaint: false cuando nada cambia.
  test('shouldRepaint es false cuando los campos son iguales', () {
    // Arrange
    final a = _painter(const Color(0xFF46B98C));
    final b = _painter(const Color(0xFF46B98C));

    // Act + Assert
    expect(b.shouldRepaint(a), isFalse);
  });

  // Pinta una flecha de celda única sin lanzar.
  test('pinta una sola celda sin lanzar', () {
    // Arrange
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = ArrowPainter(
      cells: [Position(row: 0, col: 0)],
      minCol: 0,
      minRow: 0,
      cell: 40,
      color: const Color(0xFF46B98C),
    );

    // Act + Assert
    expect(
      () => painter.paint(canvas, const Size(40, 40)),
      returnsNormally,
    );
  });
}
