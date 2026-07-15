import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/level_production/mask_spec.dart';

void main() {
  group('parseMaskSpec', () {
    test('parses a valid 2-region mask with name, dimensions and cells', () {
      // Arrange
      const text = '''
# a heart mask for the themed section
name: heart

legend:
  H = heart : #FF4D6D
  E = eyes : #202020

grid:
..HH..
.HHHH.
.EHHE.
''';

      // Act
      final spec = parseMaskSpec(text);

      // Assert
      expect(spec.name, 'heart');
      expect(spec.cols, 6);
      expect(spec.rows, 3);
      expect(spec.regions, hasLength(2));
      final heart = spec.regions.firstWhere((r) => r.glyph == 'H');
      final eyes = spec.regions.firstWhere((r) => r.glyph == 'E');
      expect(heart.role, 'heart');
      expect(heart.hex, '#FF4D6D');
      expect(heart.cells, contains(Position(row: 0, col: 2)));
      expect(eyes.cells, contains(Position(row: 2, col: 1)));
      expect(eyes.cells, contains(Position(row: 2, col: 4)));
      // Background '.' cells belong to NO region.
      final background = Position(row: 0, col: 0);
      for (final region in spec.regions) {
        expect(region.cells, isNot(contains(background)));
      }
    });

    test('palette getter returns the role -> hex map', () {
      // Arrange
      const text = '''
name: heart
legend:
  H = heart : #FF4D6D
  E = eyes : #202020
grid:
HE
''';

      // Act
      final palette = parseMaskSpec(text).palette;

      // Assert
      expect(palette, {'heart': '#FF4D6D', 'eyes': '#202020'});
    });

    test('throws when the grid contains a glyph not declared in the legend',
        () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart : #FF4D6D
grid:
.HX.
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('unknown region glyph'),
        )),
      );
    });

    test('throws when a legend entry has an invalid hex color', () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart : #FF4D
grid:
HH
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('hex'),
        )),
      );
    });

    test('throws when a legend entry is missing its hex color', () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart
grid:
HH
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('hex'),
        )),
      );
    });

    test('throws when the grid rows have unequal lengths', () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart : #FF4D6D
grid:
HH.
HH
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('not rectangular'),
        )),
      );
    });

    test('throws on a duplicate legend glyph', () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart : #FF4D6D
  H = eyes : #202020
grid:
HH
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('duplicate'),
        )),
      );
    });

    test('throws when "." is used as a legend glyph', () {
      // Arrange
      const bad = '''
name: heart
legend:
  . = background : #FFFFFF
grid:
..
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('reserved'),
        )),
      );
    });

    test('throws when the name header is missing', () {
      // Arrange
      const bad = '''
legend:
  H = heart : #FF4D6D
grid:
HH
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('name'),
        )),
      );
    });

    test('throws when there are no grid rows', () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart : #FF4D6D
grid:
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('empty grid'),
        )),
      );
    });

    test('throws when a legend glyph is not a single character', () {
      // Arrange
      const bad = '''
name: heart
legend:
  HH = heart : #FF4D6D
grid:
..
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('glyph'),
        )),
      );
    });

    test('throws when a legend glyph never appears in the grid', () {
      // Arrange
      const bad = '''
name: heart
legend:
  H = heart : #FF4D6D
  E = eyes : #202020
grid:
HH
''';

      // Act & Assert
      expect(
        () => parseMaskSpec(bad),
        throwsA(isA<MaskParseException>().having(
          (e) => e.message,
          'message',
          contains('no cells'),
        )),
      );
    });
  });
}
