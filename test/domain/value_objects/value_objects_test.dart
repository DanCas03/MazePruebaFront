import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';

void main() {
  group('LevelId', () {
    test('dos ids con el mismo valor son iguales (igualdad por valor)', () {
      // Arrange
      const a = LevelId(1);
      const b = LevelId(1);

      // Act
      final result = a == b;

      // Assert
      expect(result, isTrue);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('rechaza valores no positivos', () {
      // Arrange / Act / Assert
      expect(() => LevelId(0), throwsA(isA<AssertionError>()));
    });
  });

  group('MoveCount', () {
    test('increment devuelve una nueva instancia con un movimiento más', () {
      // Arrange
      const count = MoveCount(5);

      // Act
      final next = count.increment();

      // Assert
      expect(next.value, equals(6));
      expect(count.value, equals(5)); // inmutabilidad: el original no cambia
    });

    test('rechaza valores negativos', () {
      expect(() => MoveCount(-1), throwsA(isA<AssertionError>()));
    });
  });

  group('Position', () {
    test('igualdad por valor', () {
      // Arrange
      const a = Position(x: 2, y: 3);
      const b = Position(x: 2, y: 3);

      // Act / Assert
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('translate aplica el vector de la dirección', () {
      // Arrange
      const origin = Position(x: 1, y: 1);

      // Act
      final up = origin.translate(Direction.up);
      final right = origin.translate(Direction.right);

      // Assert
      expect(up, equals(const Position(x: 1, y: 0))); // y crece hacia abajo
      expect(right, equals(const Position(x: 2, y: 1)));
    });
  });

  group('Direction', () {
    test('rotateClockwise recorre el ciclo y vuelve al origen tras 4 giros', () {
      // Arrange
      const start = Direction.up;

      // Act
      final afterFour = start.rotateClockwise.rotateClockwise.rotateClockwise
          .rotateClockwise;

      // Assert
      expect(start.rotateClockwise, equals(Direction.right));
      expect(afterFour, equals(Direction.up));
    });

    test('fromString parsea valores válidos y usa up por defecto', () {
      // Act / Assert
      expect(DirectionBehavior.fromString('down'), equals(Direction.down));
      expect(DirectionBehavior.fromString('???'), equals(Direction.up));
    });
  });
}
