import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/presentation/game/painters/snake_exit_painter.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Painter de flecha DOBLADA: cola (0,0) → codo (1,0) → cabeza (1,1).
/// headDirection = right, canvas de 120×120, cell=40.
SnakeExitPainter _painter({double progress = 0.0}) => SnakeExitPainter(
      cells: [
        Position(row: 0, col: 0), // cola
        Position(row: 1, col: 0), // codo
        Position(row: 1, col: 1), // cabeza
      ],
      headDirection: Direction.right,
      minCol: 0,
      minRow: 0,
      cols: 4,
      rows: 4,
      cell: 40,
      color: const Color(0xFF46B98C),
      progress: progress,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('SnakeExitPainter', () {
    // Smoke: pinta sin lanzar excepción con progress=0.
    test('pinta una flecha doblada con progress=0 sin lanzar', () {
      // Arrange
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = _painter(progress: 0.0);

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(120, 120)),
        returnsNormally,
      );
    });

    // Smoke: pinta sin lanzar con progress=0.5 (mitad de animación).
    test('pinta con progress=0.5 sin lanzar', () {
      // Arrange
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = _painter(progress: 0.5);

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(120, 120)),
        returnsNormally,
      );
    });

    // Smoke: pinta sin lanzar con progress=1.0 (fin de animación).
    test('pinta con progress=1.0 sin lanzar', () {
      // Arrange
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = _painter(progress: 1.0);

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(120, 120)),
        returnsNormally,
      );
    });

    // shouldRepaint: true al cambiar progress.
    test('shouldRepaint es true al cambiar progress', () {
      // Arrange
      final a = _painter(progress: 0.0);
      final b = _painter(progress: 0.5);

      // Act
      final result = b.shouldRepaint(a);

      // Assert
      expect(result, isTrue,
          reason: 'shouldRepaint debe ser true cuando progress cambia');
    });

    // shouldRepaint: false cuando ningún campo relevante cambia.
    // Usamos la misma instancia de cells para que la comparación de identidad
    // sea igual (la implementación usa != de lista, que es identidad).
    test('shouldRepaint es false cuando ningún campo relevante cambia', () {
      // Arrange — misma lista de celdas compartida para que != sea false
      final sharedCells = [
        Position(row: 0, col: 0),
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
      ];
      const sharedColor = Color(0xFF46B98C);
      const sharedCell = 40.0;

      final a = SnakeExitPainter(
        cells: sharedCells,
        headDirection: Direction.right,
        minCol: 0,
        minRow: 0,
        cols: 4,
        rows: 4,
        cell: sharedCell,
        color: sharedColor,
        progress: 0.5,
      );
      final b = SnakeExitPainter(
        cells: sharedCells, // misma referencia → cells != cells es false
        headDirection: Direction.right,
        minCol: 0,
        minRow: 0,
        cols: 4,
        rows: 4,
        cell: sharedCell,
        color: sharedColor,
        progress: 0.5,
      );

      // Act
      final result = b.shouldRepaint(a);

      // Assert
      expect(result, isFalse,
          reason:
              'shouldRepaint debe ser false cuando progress, cells, color y cell son iguales');
    });

    // shouldRepaint: true al cambiar el color.
    test('shouldRepaint es true al cambiar el color', () {
      // Arrange
      final a = SnakeExitPainter(
        cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        headDirection: Direction.right,
        minCol: 0,
        minRow: 0,
        cols: 4,
        rows: 4,
        cell: 40,
        color: const Color(0xFF46B98C),
        progress: 0.0,
      );
      final b = SnakeExitPainter(
        cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        headDirection: Direction.right,
        minCol: 0,
        minRow: 0,
        cols: 4,
        rows: 4,
        cell: 40,
        color: const Color(0xFFD56C8E),
        progress: 0.0,
      );

      // Act
      final result = b.shouldRepaint(a);

      // Assert
      expect(result, isTrue,
          reason: 'shouldRepaint debe ser true cuando el color cambia');
    });

    // Smoke: flecha de una sola celda no lanza.
    test('pinta una sola celda sin lanzar', () {
      // Arrange
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = SnakeExitPainter(
        cells: [Position(row: 0, col: 0)],
        headDirection: Direction.right,
        minCol: 0,
        minRow: 0,
        cols: 4,
        rows: 4,
        cell: 40,
        color: const Color(0xFF46B98C),
        progress: 0.5,
      );

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(40, 40)),
        returnsNormally,
      );
    });

    // Lista de celdas vacía: no lanza (guarda de `if (cells.isEmpty) return`).
    test('cells vacías no lanza', () {
      // Arrange
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = SnakeExitPainter(
        cells: const [],
        headDirection: Direction.right,
        minCol: 0,
        minRow: 0,
        cols: 4,
        rows: 4,
        cell: 40,
        color: const Color(0xFF46B98C),
        progress: 0.5,
      );

      // Act + Assert
      expect(
        () => painter.paint(canvas, const Size(40, 40)),
        returnsNormally,
      );
    });
  });
}
