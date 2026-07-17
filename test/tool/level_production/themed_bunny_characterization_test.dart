import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_decoder.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

import '../../../tool/level_production/mask_spec.dart';

// ---------------------------------------------------------------------------
// Caracterización del conejo CONGELADO (#118): `themed-bunny.json` es el
// benchmark estético del maintainer y NO se regenera. La Task 7 solo le añade
// la clave `silhouette` (derivada de `bunny.mask`, vía el one-off
// `tool/level_production/add_silhouette.dart`), con las 37 flechas intactas.
// Estos tests congelan ese contrato: si alguien regenera el conejo o toca una
// flecha, esto se pone rojo con nombre y apellido.
// ---------------------------------------------------------------------------

const _fixturePath = 'tool/level_production/themed/themed-bunny.json';
const _maskPath = 'tool/level_production/masks/bunny.mask';

/// Las 37 flechas del conejo, congeladas literalmente (id|headDir|paintRole|
/// celdas en orden). Capturadas del fixture aprobado ANTES de añadir la
/// silueta; el orden de la lista también está congelado (el JSON es
/// byte-estable).
const _frozenArrows = [
  'arrow-0|up|eye|13,5;12,5;12,4',
  'arrow-1|up|eye|13,10;12,10;12,11',
  'arrow-2|right|pink|3,10;4,10;4,11;3,11;2,11',
  'arrow-3|left|pink|6,10;7,10;7,11;6,11;5,11',
  'arrow-4|down|pink|15,8;15,7',
  'arrow-5|left|pink|5,5;4,5;3,5;3,4;2,4',
  'arrow-6|left|pink|8,4;7,4;7,5;6,5;6,4;5,4',
  'arrow-7|up|fur|4,3;3,3;2,3;1,3',
  'arrow-8|left|fur|17,3;17,4;17,5;17,6;16,6',
  'arrow-9|left|fur|1,11;0,11',
  'arrow-10|up|fur|11,10;11,9;11,8',
  'arrow-11|down|fur|15,13;14,13;13,13;12,13;12,12;13,12',
  'arrow-12|down|fur|18,5;18,6;18,7',
  'arrow-13|left|fur|12,2;13,2;14,2;15,2;15,3;15,4;16,4',
  'arrow-14|up|fur|10,8;10,9;10,10;9,10;9,11;9,12;8,12',
  'arrow-15|down|fur|13,9;14,9;14,10;14,11',
  'arrow-16|left|fur|13,7;13,6;12,6;12,7;11,7;11,6;11,5;11,4',
  'arrow-17|up|fur|7,12;6,12;5,12;4,12;3,12;2,12;1,12',
  'arrow-18|down|fur|15,10;15,9;16,9;16,8',
  'arrow-19|left|fur|10,4;10,3',
  'arrow-20|up|fur|8,10;8,9;7,9',
  'arrow-21|down|fur|17,10;16,10;16,11;15,11;15,12;16,12',
  'arrow-22|up|fur|8,6;9,6;10,6;10,7',
  'arrow-23|left|fur|5,3;6,3;7,3;8,3',
  'arrow-24|down|fur|16,7;17,7;17,8;17,9',
  'arrow-25|up|fur|9,9;9,8;8,8;8,7',
  'arrow-26|up|fur|6,9;5,9;4,9;3,9',
  'arrow-27|left|fur|14,3;14,4;13,4;13,3;12,3;11,3',
  'arrow-28|right|fur|11,11;10,11;10,12',
  'arrow-29|up|fur|2,5;1,5;1,4;0,4',
  'arrow-30|up|fur|7,6;6,6;5,6',
  'arrow-31|down|fur|19,8;19,7',
  'arrow-32|up|fur|4,6;3,6;2,6',
  'arrow-33|down|fur|17,12;17,11',
  'arrow-34|down|fur|18,8;18,9',
  'arrow-35|left|fur|8,5;9,5;9,4',
  'arrow-36|up|fur|2,9;2,10',
];

/// El fixture normalizado a LF: en el worktree de Windows el checkout es CRLF
/// (`.gitattributes`/autocrlf), pero el artefacto congelado en git es LF.
String _readFixture() =>
    File(_fixturePath).readAsStringSync().replaceAll('\r\n', '\n');

Level _decodeFixture() => const LevelJsonDecoder()
    .decode(jsonDecode(_readFixture()) as Map<String, Object?>);

void main() {
  group('themed-bunny.json — caracterización del conejo congelado (#118)', () {
    test('conserva EXACTAMENTE las 37 flechas congeladas (ids, dirección, '
        'rol y celdas, en orden)', () {
      // Arrange
      final level = _decodeFixture();

      // Act
      final actual = [
        for (final a in level.board.arrows)
          '${a.id.value}|${a.headDirection.name}|${a.paintRole}|'
              '${a.cells.map((c) => '${c.row},${c.col}').join(';')}',
      ];

      // Assert
      expect(actual.length, 37);
      expect(actual, _frozenArrows);
    });

    test('gana la clave silhouette == regiones de bunny.mask (fill completo, '
        'rol a rol)', () {
      // Arrange
      final level = _decodeFixture();
      final mask = parseMaskSpec(File(_maskPath).readAsStringSync());

      // Act
      final silhouette = level.silhouette;

      // Assert
      expect(silhouette, isNotNull,
          reason: 'el conejo debe ganar la clave silhouette (#118)');
      expect(silhouette!.keys.toSet(),
          mask.regions.map((r) => r.role).toSet());
      for (final region in mask.regions) {
        expect(silhouette[region.role], region.cells,
            reason: 'la silueta de "${region.role}" debe ser el fill completo '
                'de la región de bunny.mask');
      }
    });

    test('byte-estable: encode(decode(x)) reproduce el fixture', () {
      // Arrange
      final raw = _readFixture();
      final level = _decodeFixture();

      // Act
      final reEncoded = const LevelJsonEncoder().encode(
        levelId: level.id.value,
        board: level.board,
        palette: level.palette,
        silhouette: level.silhouette,
      );

      // Assert
      expect(reEncoded, raw);
    });

    test('metadatos congelados: 16×20, palette intacta, sin order/'
        'timeLimitSec/maxErrors en el wire', () {
      // Arrange
      final raw = jsonDecode(_readFixture()) as Map<String, dynamic>;
      final level = _decodeFixture();

      // Act + Assert
      expect(level.id.value, 'themed-bunny');
      expect(level.board.cols, 16);
      expect(level.board.rows, 20);
      expect(level.palette, {
        'fur': '#F5F5F5',
        'pink': '#FF9EB5',
        'eye': '#2B2B2B',
      });
      expect(raw.containsKey('order'), isFalse);
      expect(raw.containsKey('timeLimitSec'), isFalse);
      expect(raw.containsKey('maxErrors'), isFalse);
    });
  });
}
