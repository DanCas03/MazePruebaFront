import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import '../../support/arrow_fixtures.dart';

void main() {
  // ── straightArrow (flecha recta) ──────────────────────────────────────────
  // La geometría del carril de salida (exitPath) se probaba aquí; tras el
  // refactor BoardSpace (front#73, ADR-0005) vive en rect_space_test.dart
  // (BoardSpace.exitLane). Arrow es dato puro: solo se prueban forma y datos.
  group('straightArrow (flecha recta)', () {
    // Horizontal flecha: tail=(1,0) dir=right length=3 → celdas (1,0),(1,1),(1,2)
    late Arrow sut;

    setUp(() {
      sut = straightArrow(
        id: const ArrowId('a1'),
        tail: Position(row: 1, col: 0),
        direction: Direction.right,
        length: 3,
      );
    });

    test('cells va de tail a head en orden cola→cabeza', () {
      // Arrange — sut creado en setUp
      // Act — acceder a cells
      final cells = sut.cells;
      // Assert
      expect(cells, [
        Position(row: 1, col: 0),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ]);
    });

    test('tail es la primera celda de cells', () {
      // Arrange — sut creado en setUp
      // Act
      final tail = sut.tail;
      // Assert
      expect(tail, Position(row: 1, col: 0));
    });

    test('head es la última celda de cells', () {
      // Arrange — sut creado en setUp
      // Act
      final head = sut.head;
      // Assert
      expect(head, Position(row: 1, col: 2));
    });

    test('length es la cantidad de celdas', () {
      // Arrange — sut creado en setUp
      // Act
      final len = sut.length;
      // Assert
      expect(len, 3);
    });

    test('direction es igual a headDirection', () {
      // Arrange — sut creado en setUp
      // Act / Assert
      expect(sut.direction, Direction.right);
      expect(sut.direction, sut.headDirection);
    });

    // straightArrow equivale a un camino recto explícito (Equatable)
    test('straightArrow es igual por Equatable a un Arrow con cells explícito equivalente', () {
      // Arrange
      final straight = straightArrow(
        id: const ArrowId('eq1'),
        tail: Position(row: 0, col: 0),
        direction: Direction.down,
        length: 2,
      );
      final explicit = Arrow(
        id: const ArrowId('eq1'),
        cells: [Position(row: 0, col: 0), Position(row: 1, col: 0)],
        headDirection: Direction.down,
      );
      // Act / Assert
      expect(straight, equals(explicit));
    });
  });

  // ── Arrow con camino DOBLADO (curva en el cuerpo) ─────────────────────────
  group('Arrow con camino doblado (L-shape)', () {
    // Flecha en L: sube 2 filas (tail→body) y luego gira a la derecha
    // cells: (3,1) → (2,1) → (1,1) → (1,2)
    // headDirection = right
    // El último segmento del cuerpo es vertical (up) pero la cabeza apunta right.
    late Arrow sut;

    setUp(() {
      sut = Arrow(
        id: const ArrowId('bent1'),
        cells: [
          Position(row: 3, col: 1), // tail
          Position(row: 2, col: 1),
          Position(row: 1, col: 1), // curva: aquí el cuerpo giraba
          Position(row: 1, col: 2), // head
        ],
        headDirection: Direction.right,
      );
    });

    test('tail es la primera celda', () {
      // Act / Assert
      expect(sut.tail, Position(row: 3, col: 1));
    });

    test('head es la última celda', () {
      // Act / Assert
      expect(sut.head, Position(row: 1, col: 2));
    });

    test('length es 4 (número de celdas del camino)', () {
      // Act / Assert
      expect(sut.length, 4);
    });

    test('direction retorna headDirection (right), no la dirección del penúltimo segmento', () {
      // Act / Assert — el último segmento del cuerpo es vertical (up) pero
      // direction/headDirection deben ser right.
      expect(sut.direction, Direction.right);
    });

    test('cells contiene todas las posiciones en orden cola→cabeza', () {
      // Act / Assert
      expect(sut.cells, [
        Position(row: 3, col: 1),
        Position(row: 2, col: 1),
        Position(row: 1, col: 1),
        Position(row: 1, col: 2),
      ]);
    });
  });

  // ── Caso con CURVA justo en la cabeza ─────────────────────────────────────
  group('Arrow con curva justo en la cabeza (último segmento perpendicular a headDirection)', () {
    // El último segmento del cuerpo va hacia abajo (down), pero headDirection = right.
    // cells: (0,0) → (1,0) → (2,0) → (2,1)
    late Arrow sut;

    setUp(() {
      sut = Arrow(
        id: const ArrowId('head-curve'),
        cells: [
          Position(row: 0, col: 0), // tail
          Position(row: 1, col: 0), // cuerpo, dirección down
          Position(row: 2, col: 0), // penúltima celda, última antes de la curva
          Position(row: 2, col: 1), // head — curva justo aquí (cuerpo venía de arriba)
        ],
        headDirection: Direction.right,
      );
    });

    test('direction getter devuelve headDirection aunque el cuerpo venga de otra dirección', () {
      // Act / Assert
      expect(sut.direction, Direction.right);
      expect(sut.headDirection, Direction.right);
    });
  });

  // front#67 — paintRole es un dato opaco (Instrucciones de pintado, ADR 0004):
  // nulo en campaña, presente en flechas de niveles temáticos. No afecta la
  // mecánica; solo lo consume el seam de color en presentación.
  group('Arrow.paintRole (opaque paint role)', () {
    test('paintRole por defecto es null cuando no se provee', () {
      // Arrange / Act
      final arrow = straightArrow(
        id: const ArrowId('a1'),
        tail: Position(row: 0, col: 0),
        direction: Direction.right,
        length: 2,
      );
      // Assert
      expect(arrow.paintRole, isNull);
    });

    test('straightArrow propaga paintRole cuando se provee', () {
      // Arrange / Act
      final arrow = straightArrow(
        id: const ArrowId('a1'),
        tail: Position(row: 0, col: 0),
        direction: Direction.right,
        length: 2,
        paintRole: 'cara',
      );
      // Assert
      expect(arrow.paintRole, 'cara');
    });

    test('dos flechas iguales salvo paintRole no son iguales', () {
      // Arrange
      final cells = [Position(row: 0, col: 0), Position(row: 0, col: 1)];
      final a = Arrow(
          id: const ArrowId('a1'),
          cells: cells,
          headDirection: Direction.right,
          paintRole: 'cara');
      final b = Arrow(
          id: const ArrowId('a1'),
          cells: cells,
          headDirection: Direction.right,
          paintRole: 'ojo');
      // Act / Assert
      expect(a == b, isFalse);
    });
  });
}
