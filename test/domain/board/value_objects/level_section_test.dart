import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';

void main() {
  group('LevelSection.fromWire', () {
    test('mapea el literal exacto "themed" a themed', () {
      // Arrange / Act / Assert
      expect(LevelSection.fromWire('themed'), LevelSection.themed);
    });

    test('mapea "campaign" a campaign', () {
      // Arrange / Act / Assert
      expect(LevelSection.fromWire('campaign'), LevelSection.campaign);
    });

    test('degrada null a campaign (aditivo: sección ausente ⇒ campaña)', () {
      // Arrange / Act / Assert
      expect(LevelSection.fromWire(null), LevelSection.campaign);
    });

    test('degrada valores desconocidos a campaign (tolerante)', () {
      // Arrange / Act / Assert
      expect(LevelSection.fromWire('seasonal'), LevelSection.campaign);
      expect(LevelSection.fromWire(''), LevelSection.campaign);
      expect(LevelSection.fromWire('Themed'), LevelSection.campaign);
    });

    test('fromWire maps the exact literal "hex" to LevelSection.hex', () {
      // Arrange & Act & Assert
      expect(LevelSection.fromWire('hex'), LevelSection.hex);
    });

    test('fromWire degrades unknown values to campaign, hex is exact-match only', () {
      // Arrange & Act & Assert — sólo el literal exacto cuenta (tolerante).
      expect(LevelSection.fromWire('HEX'), LevelSection.campaign);
      expect(LevelSection.fromWire('hexagonal'), LevelSection.campaign);
      expect(LevelSection.fromWire(null), LevelSection.campaign);
    });
  });
}
