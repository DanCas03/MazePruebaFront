import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_blueprint.dart';

void main() {
  // ── Representative sample levels used across multiple tests ────────────────
  const sampleLevels = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 25, 30, 45, 60, 100];

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 1 — nivel 1 (valores mínimos de la curva)
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — nivel 1 (mínimos de curva)', () {
    test('nivel 1 produce tablero 6×8 con maxPathLen 3', () {
      // Arrange — nivel inicial de la curva vertical-densa
      const level = 1;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert — valores exactos de la fórmula en lvl=1
      expect(bp.cols, 6, reason: 'width = (6+(1-1)~/3).clamp(6,11) = 6');
      expect(bp.rows, 8, reason: 'height = (8+(1-1)~/2).clamp(8,15) = 8');
      expect(bp.maxPathLen, 3, reason: 'maxPathLen = (3+(1-1)~/2).clamp(3,12) = 3');
    });

    test('nivel 1: arrowCount está dentro de [4, cols×rows]', () {
      // Arrange
      const level = 1;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert
      expect(bp.arrowCount, greaterThanOrEqualTo(4));
      expect(bp.arrowCount, lessThanOrEqualTo(bp.cols * bp.rows));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 2 — clamps inferiores: niveles ≤ 0 normalizan a 1
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — normalización nivel < 1', () {
    test('nivel 0 se normaliza a nivel 1 (6×8, maxPathLen 3)', () {
      // Arrange
      final bpZero = LevelBlueprint.forLevel(0);
      final bpOne  = LevelBlueprint.forLevel(1);

      // Act — comparación directa de campos
      // Assert
      expect(bpZero.cols,       bpOne.cols);
      expect(bpZero.rows,       bpOne.rows);
      expect(bpZero.maxPathLen, bpOne.maxPathLen);
      expect(bpZero.arrowCount, bpOne.arrowCount);
    });

    test('nivel negativo (-5) se normaliza a nivel 1 (6×8, maxPathLen 3)', () {
      // Arrange
      final bpNeg = LevelBlueprint.forLevel(-5);
      final bpOne = LevelBlueprint.forLevel(1);

      // Act — comparación directa de campos
      // Assert
      expect(bpNeg.cols,       bpOne.cols);
      expect(bpNeg.rows,       bpOne.rows);
      expect(bpNeg.maxPathLen, bpOne.maxPathLen);
      expect(bpNeg.arrowCount, bpOne.arrowCount);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 3 — propiedad vertical: rows ≥ cols en toda la curva
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — tablero siempre vertical (rows >= cols)', () {
    test('rows >= cols para niveles representativos de toda la curva', () {
      // Arrange — muestra amplia: inicio, crecimiento, saturación
      for (final lvl in sampleLevels) {
        // Act
        final bp = LevelBlueprint.forLevel(lvl);

        // Assert
        expect(
          bp.rows,
          greaterThanOrEqualTo(bp.cols),
          reason: 'nivel $lvl: rows=${bp.rows} debe ser >= cols=${bp.cols}',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 4 — clamps superiores: niveles altos saturan en 11×15, maxPathLen 12
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — clamps superiores', () {
    test('nivel 20 alcanza cols=11, rows=15, maxPathLen=12', () {
      // Arrange — nivel donde la fórmula raw supera todos los clamps superiores
      const level = 20;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert
      expect(bp.cols,       11, reason: 'cols clamped a 11');
      expect(bp.rows,       15, reason: 'rows clamped a 15');
      expect(bp.maxPathLen, 12, reason: 'maxPathLen clamped a 12');
    });

    test('ningún nivel produce cols > 11, rows > 15 o maxPathLen > 12', () {
      // Arrange — verificar clamp superior en muestra amplia + altos
      final highLevels = [...sampleLevels, 200, 500, 1000];

      for (final lvl in highLevels) {
        // Act
        final bp = LevelBlueprint.forLevel(lvl);

        // Assert
        expect(bp.cols,       lessThanOrEqualTo(11), reason: 'nivel $lvl: cols=${bp.cols}');
        expect(bp.rows,       lessThanOrEqualTo(15), reason: 'nivel $lvl: rows=${bp.rows}');
        expect(bp.maxPathLen, lessThanOrEqualTo(12), reason: 'nivel $lvl: maxPathLen=${bp.maxPathLen}');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 5 — arrowCount dentro de [4, cols×rows] en toda la curva
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — arrowCount dentro de límites', () {
    test('arrowCount en [4, cols×rows] para niveles representativos', () {
      // Arrange — muestra que cubre inicio, crecimiento, plateau de saturación
      for (final lvl in sampleLevels) {
        // Act
        final bp = LevelBlueprint.forLevel(lvl);

        // Assert
        expect(
          bp.arrowCount,
          greaterThanOrEqualTo(4),
          reason: 'nivel $lvl: arrowCount=${bp.arrowCount} debe ser >= 4',
        );
        expect(
          bp.arrowCount,
          lessThanOrEqualTo(bp.cols * bp.rows),
          reason:
              'nivel $lvl: arrowCount=${bp.arrowCount} debe ser <= ${bp.cols * bp.rows}',
        );
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 6 — monotonía no decreciente de cols, rows y maxPathLen
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — monotonía no decreciente', () {
    test('cols es no decreciente de nivel 1 a 100', () {
      // Arrange
      var prev = 0;

      // Act + Assert (propiedad iterativa sobre un único escenario)
      for (var lvl = 1; lvl <= 100; lvl++) {
        final bp = LevelBlueprint.forLevel(lvl);
        expect(
          bp.cols,
          greaterThanOrEqualTo(prev),
          reason: 'cols decreció en nivel $lvl: $prev → ${bp.cols}',
        );
        prev = bp.cols;
      }
    });

    test('rows es no decreciente de nivel 1 a 100', () {
      // Arrange
      var prev = 0;

      // Act + Assert
      for (var lvl = 1; lvl <= 100; lvl++) {
        final bp = LevelBlueprint.forLevel(lvl);
        expect(
          bp.rows,
          greaterThanOrEqualTo(prev),
          reason: 'rows decreció en nivel $lvl: $prev → ${bp.rows}',
        );
        prev = bp.rows;
      }
    });

    test('maxPathLen es no decreciente de nivel 1 a 100', () {
      // Arrange
      var prev = 0;

      // Act + Assert
      for (var lvl = 1; lvl <= 100; lvl++) {
        final bp = LevelBlueprint.forLevel(lvl);
        expect(
          bp.maxPathLen,
          greaterThanOrEqualTo(prev),
          reason: 'maxPathLen decreció en nivel $lvl: $prev → ${bp.maxPathLen}',
        );
        prev = bp.maxPathLen;
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // GROUP 7 — valores puntuales verificados contra la fórmula
  //           (niveles donde cambia al menos un parámetro)
  // ══════════════════════════════════════════════════════════════════════════
  group('LevelBlueprint.forLevel — valores puntuales de la curva', () {
    // Cada test cubre un nivel de transición distinto.

    test('nivel 3: cols=6, rows=9, maxPathLen=4', () {
      // Arrange
      const level = 3;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert — (6+(2)~/3)=6, (8+(2)~/2)=9, (3+(2)~/2)=4
      expect(bp.cols,       6);
      expect(bp.rows,       9);
      expect(bp.maxPathLen, 4);
    });

    test('nivel 4: cols=7, rows=9, maxPathLen=4', () {
      // Arrange
      const level = 4;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert — (6+(3)~/3)=7, (8+(3)~/2)=9, (3+(3)~/2)=4
      expect(bp.cols,       7);
      expect(bp.rows,       9);
      expect(bp.maxPathLen, 4);
    });

    test('nivel 10: cols=9, rows=12, maxPathLen=7', () {
      // Arrange
      const level = 10;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert — (6+(9)~/3)=9, (8+(9)~/2)=12, (3+(9)~/2)=7
      expect(bp.cols,       9);
      expect(bp.rows,       12);
      expect(bp.maxPathLen, 7);
    });

    test('nivel 30: cols=11, rows=15, maxPathLen=12 (todos clamped)', () {
      // Arrange
      const level = 30;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert — todos clamped en sus máximos
      expect(bp.cols,       11);
      expect(bp.rows,       15);
      expect(bp.maxPathLen, 12);
    });

    test('nivel 60: cols=11, rows=15, maxPathLen=12 (plateau estable)', () {
      // Arrange
      const level = 60;

      // Act
      final bp = LevelBlueprint.forLevel(level);

      // Assert — plateau: mismos máximos que nivel 30
      expect(bp.cols,       11);
      expect(bp.rows,       15);
      expect(bp.maxPathLen, 12);
    });
  });
}
