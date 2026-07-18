import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardSpace.masked (seam polimórfico front#125)', () {
    test('RectSpace produce un MaskedSpace con las mismas dimensiones y celdas', () {
      // Arrange
      const space = RectSpace(3, 3);
      final active = {Position(row: 0, col: 0), Position(row: 1, col: 1)};

      // Act
      final masked = space.masked(active);

      // Assert
      expect(masked, isA<MaskedSpace>());
      expect(masked, MaskedSpace(3, 3, activeCells: active));
    });

    test('HexSpace produce un HexMaskedSpace con el mismo radio y celdas', () {
      // Arrange
      const space = HexSpace(2);
      final active = {Position(row: 2, col: 2), Position(row: 2, col: 3)};

      // Act
      final masked = space.masked(active);

      // Assert
      expect(masked, isA<HexMaskedSpace>());
      expect(masked, HexMaskedSpace(2, activeCells: active));
    });
  });
}
