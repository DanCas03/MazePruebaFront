import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_blueprint.dart';

void main() {
  group('LevelBlueprint.forLevel', () {
    test('nivel 1 produce el tablero mínimo cuadrado', () {
      // Arrange / Act
      final bp = LevelBlueprint.forLevel(1);
      // Assert
      expect(bp.cols, 4);
      expect(bp.rows, 4);
      expect(bp.cols, bp.rows);
      expect(bp.arrowCount, greaterThanOrEqualTo(4));
    });

    test('el tamaño crece con el nivel y se topa en 9', () {
      // Arrange / Act / Assert
      expect(LevelBlueprint.forLevel(1).cols, 4);
      expect(LevelBlueprint.forLevel(7).cols, greaterThan(4));
      expect(LevelBlueprint.forLevel(100).cols, 9);
    });

    test('size y arrowCount son monótonos no decrecientes', () {
      // Arrange
      var prevSize = 0;
      var prevArrows = 0;
      // Act + Assert (iterativo, un único escenario de propiedades)
      for (var lvl = 1; lvl <= 30; lvl++) {
        final bp = LevelBlueprint.forLevel(lvl);
        expect(bp.cols, greaterThanOrEqualTo(prevSize));
        expect(bp.arrowCount, greaterThanOrEqualTo(prevArrows));
        prevSize = bp.cols;
        prevArrows = bp.arrowCount;
      }
    });

    test('niveles fuera de rango no rompen (clamp)', () {
      // Arrange / Act / Assert
      expect(LevelBlueprint.forLevel(0).cols, 4);
      expect(LevelBlueprint.forLevel(-5).cols, 4);
    });
  });
}
