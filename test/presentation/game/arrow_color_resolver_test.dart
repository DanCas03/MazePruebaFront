import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/arrow_color.dart';
import 'package:flutter_arrow_maze/presentation/game/arrow_color_resolver.dart';
import '../../support/arrow_fixtures.dart';

// front#67 — seam de color: dos adapters intercambiables. El default reproduce
// la paleta por identidad (campaña); el temático resuelve rol→hex y cae a
// identidad ante rol/hex ausente o inválido.

Arrow _arrow(String id, {String? paintRole}) => straightArrow(
      id: ArrowId(id),
      tail: Position(row: 0, col: 0),
      direction: Direction.right,
      length: 2,
      paintRole: paintRole,
    );

void main() {
  group('IdentityArrowColorResolver', () {
    const sut = IdentityArrowColorResolver();

    test('reproduces the identity-hash color and ignores the palette', () {
      // Arrange
      final arrow = _arrow('arrow-3', paintRole: 'cara');
      // Act
      final withoutPalette = sut.colorFor(arrow, null);
      final withPalette = sut.colorFor(arrow, const {'cara': '#FBBF24'});
      // Assert — matches the pre-seam function and never looks at the palette.
      expect(withoutPalette, arrowColorFor(arrow.id));
      expect(withPalette, arrowColorFor(arrow.id));
    });
  });

  group('ThemedArrowColorResolver', () {
    const sut = ThemedArrowColorResolver();

    test('resolves paintRole to its palette hex as an opaque color', () {
      // Arrange
      final arrow = _arrow('a1', paintRole: 'cara');
      // Act
      final color = sut.colorFor(arrow, const {'cara': '#FBBF24'});
      // Assert
      expect(color, const Color(0xFFFBBF24));
    });

    test('falls back to identity when the arrow has no paintRole', () {
      // Arrange
      final arrow = _arrow('arrow-2');
      // Act
      final color = sut.colorFor(arrow, const {'cara': '#FBBF24'});
      // Assert
      expect(color, arrowColorFor(arrow.id));
    });

    test('falls back to identity when the palette is null (campaign)', () {
      // Arrange
      final arrow = _arrow('arrow-2', paintRole: 'cara');
      // Act
      final color = sut.colorFor(arrow, null);
      // Assert
      expect(color, arrowColorFor(arrow.id));
    });

    test('falls back to identity when the role is absent from the palette', () {
      // Arrange
      final arrow = _arrow('arrow-2', paintRole: 'ojo');
      // Act
      final color = sut.colorFor(arrow, const {'cara': '#FBBF24'});
      // Assert
      expect(color, arrowColorFor(arrow.id));
    });

    test('falls back to identity when the hex is malformed', () {
      // Arrange
      final arrow = _arrow('arrow-2', paintRole: 'cara');
      // Act
      final color = sut.colorFor(arrow, const {'cara': 'not-a-hex'});
      // Assert
      expect(color, arrowColorFor(arrow.id));
    });
  });

  group('ThemedArrowColorResolver.parseHexColor', () {
    test('parses #RRGGBB as an opaque color', () {
      // Arrange / Act / Assert
      expect(ThemedArrowColorResolver.parseHexColor('#FBBF24'),
          const Color(0xFFFBBF24));
    });

    test('parses #AARRGGBB verbatim', () {
      // Arrange / Act / Assert
      expect(ThemedArrowColorResolver.parseHexColor('#80FBBF24'),
          const Color(0x80FBBF24));
    });

    test('returns null for a wrong-length or non-hex string', () {
      // Arrange / Act / Assert
      expect(ThemedArrowColorResolver.parseHexColor('#FFF'), isNull);
      expect(ThemedArrowColorResolver.parseHexColor('#GGGGGG'), isNull);
    });
  });
}
