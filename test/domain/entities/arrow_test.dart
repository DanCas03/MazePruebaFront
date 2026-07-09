import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';

void main() {
  // ── Arrow.straight ────────────────────────────────────────────────────────
  group('Arrow.straight', () {
    // Horizontal flecha: tail=(1,0) dir=right length=3 → celdas (1,0),(1,1),(1,2)
    late Arrow sut;

    setUp(() {
      sut = Arrow.straight(
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

    // Arrow.straight equivale a un camino recto explícito (Equatable)
    test('Arrow.straight es igual por Equatable a un Arrow con cells explícito equivalente', () {
      // Arrange
      final straight = Arrow.straight(
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

    // ── exitPath — 4 direcciones ─────────────────────────────────────────────

    test('exitPath direction=right devuelve celdas desde head+1 hasta el borde derecho', () {
      // Arrange — flecha right: head=(1,2), board 5 cols → salida (1,3),(1,4)
      final arrow = Arrow.straight(
        id: const ArrowId('r1'),
        tail: Position(row: 1, col: 0),
        direction: Direction.right,
        length: 3,
      );
      // Act
      final path = arrow.exitPath(5, 5);
      // Assert
      expect(path, [
        Position(row: 1, col: 3),
        Position(row: 1, col: 4),
      ]);
    });

    test('exitPath direction=left devuelve celdas desde head-1 hasta el borde izquierdo', () {
      // Arrange — flecha left: tail=(2,4), head=(2,2), board 5 cols → salida (2,1),(2,0)
      final arrow = Arrow.straight(
        id: const ArrowId('l1'),
        tail: Position(row: 2, col: 4),
        direction: Direction.left,
        length: 3,
      );
      // Act
      final path = arrow.exitPath(5, 5);
      // Assert
      expect(path, [
        Position(row: 2, col: 1),
        Position(row: 2, col: 0),
      ]);
    });

    test('exitPath direction=down devuelve celdas desde head+1 hasta el borde inferior', () {
      // Arrange — flecha down: tail=(0,3), head=(1,3), board 5 rows → salida (2,3),(3,3),(4,3)
      final arrow = Arrow.straight(
        id: const ArrowId('d1'),
        tail: Position(row: 0, col: 3),
        direction: Direction.down,
        length: 2,
      );
      // Act
      final path = arrow.exitPath(5, 5);
      // Assert
      expect(path, [
        Position(row: 2, col: 3),
        Position(row: 3, col: 3),
        Position(row: 4, col: 3),
      ]);
    });

    test('exitPath direction=up devuelve celdas desde head-1 hasta el borde superior', () {
      // Arrange — flecha up: tail=(4,1), head=(3,1), board 5 rows → salida (2,1),(1,1),(0,1)
      final arrow = Arrow.straight(
        id: const ArrowId('u1'),
        tail: Position(row: 4, col: 1),
        direction: Direction.up,
        length: 2,
      );
      // Act
      final path = arrow.exitPath(5, 5);
      // Assert
      expect(path, [
        Position(row: 2, col: 1),
        Position(row: 1, col: 1),
        Position(row: 0, col: 1),
      ]);
    });

    // ── exitPath vacío en el borde ─────────────────────────────────────────

    test('exitPath está vacío cuando la cabeza ya está en el borde derecho', () {
      // Arrange — head en col 3 de un board de 4 cols
      final arrow = Arrow.straight(
        id: const ArrowId('re'),
        tail: Position(row: 0, col: 1),
        direction: Direction.right,
        length: 3, // head=(0,3)
      );
      // Act / Assert
      expect(arrow.exitPath(4, 4), isEmpty);
    });

    test('exitPath está vacío cuando la cabeza ya está en el borde izquierdo', () {
      // Arrange — head en col 0 de un board de 4 cols
      final arrow = Arrow.straight(
        id: const ArrowId('le'),
        tail: Position(row: 0, col: 2),
        direction: Direction.left,
        length: 3, // head=(0,0)
      );
      // Act / Assert
      expect(arrow.exitPath(4, 4), isEmpty);
    });

    test('exitPath está vacío cuando la cabeza ya está en el borde inferior', () {
      // Arrange — head en row 3 de un board de 4 rows
      final arrow = Arrow.straight(
        id: const ArrowId('de'),
        tail: Position(row: 1, col: 0),
        direction: Direction.down,
        length: 3, // head=(3,0)
      );
      // Act / Assert
      expect(arrow.exitPath(4, 4), isEmpty);
    });

    test('exitPath está vacío cuando la cabeza ya está en el borde superior', () {
      // Arrange — head en row 0 de un board de 4 rows
      final arrow = Arrow.straight(
        id: const ArrowId('ue'),
        tail: Position(row: 2, col: 0),
        direction: Direction.up,
        length: 3, // head=(0,0)
      );
      // Act / Assert
      expect(arrow.exitPath(4, 4), isEmpty);
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

    test('exitPath sigue headDirection (right) y no el último segmento del cuerpo (up)', () {
      // Arrange — board 6x6, head=(1,2), headDirection=right
      // exitPath debe ser (1,3),(1,4),(1,5) — en dirección right desde la cabeza.
      // Si erroneamente siguiera el último segmento del cuerpo (up), sería
      // (0,2) en vez de (1,3).
      // Act
      final path = sut.exitPath(6, 6);
      // Assert
      expect(path, [
        Position(row: 1, col: 3),
        Position(row: 1, col: 4),
        Position(row: 1, col: 5),
      ]);
      // Garantizar que no contiene celdas en dirección up
      expect(path, isNot(contains(Position(row: 0, col: 2))));
    });

    test('exitPath vacío cuando la cabeza del camino doblado ya está en el borde', () {
      // Arrange — flecha doblada con head en el borde derecho (col 5 de board 6)
      final bentAtEdge = Arrow(
        id: const ArrowId('bent-edge'),
        cells: [
          Position(row: 3, col: 1),
          Position(row: 3, col: 2),
          Position(row: 3, col: 3),
          Position(row: 2, col: 3),
          Position(row: 1, col: 3),
          Position(row: 1, col: 4),
          Position(row: 1, col: 5), // head en borde derecho del board 6x6
        ],
        headDirection: Direction.right,
      );
      // Act / Assert
      expect(bentAtEdge.exitPath(6, 6), isEmpty);
    });
  });

  // ── Caso con CURVA justo en la cabeza ─────────────────────────────────────
  group('Arrow con curva justo en la cabeza (último segmento perpendicular a headDirection)', () {
    // El último segmento del cuerpo va hacia abajo (down), pero headDirection = right.
    // La cabeza es la celda que cambia de dirección; exitPath debe ser right.
    // cells: (0,0) → (1,0) → (2,0) → (2,1)
    // headDirection = right   ← curva justo al llegar a la cabeza
    // el penúltimo→último movimiento fue down→right, pero headDirection es right.
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

    test('exitPath sigue headDirection=right, no el último segmento del cuerpo (down)', () {
      // Arrange — board 5x5, head=(2,1), headDirection=right
      // exitPath correcto: (2,2),(2,3),(2,4)
      // exitPath incorrecto (si siguiera el body): (3,1),(4,1)
      // Act
      final path = sut.exitPath(5, 5);
      // Assert — dirección correcta
      expect(path, [
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
        Position(row: 2, col: 4),
      ]);
      // No debe contener celdas en dirección down desde la cabeza
      expect(path, isNot(contains(Position(row: 3, col: 1))));
    });

    test('direction getter devuelve headDirection aunque el cuerpo venga de otra dirección', () {
      // Act / Assert
      expect(sut.direction, Direction.right);
      expect(sut.headDirection, Direction.right);
    });
  });
}
