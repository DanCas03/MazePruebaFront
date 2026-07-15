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
  });
}
