import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../../tool/level_production/mask_spec.dart';
import '../../../tool/level_production/themed_producer.dart';

/// Máscara mini de 2 regiones (6×4) usada por todos los tests: pequeña,
/// determinista y con dos roles/colores distintos.
const _miniMask = '''
name: mini
legend:
  A = alpha : #FF0000
  B = beta : #0000FF
grid:
AAA...
AAA...
...BBB
...BBB
''';

/// GOLDEN: salida byte-estable de `produceThemed(mini, seeds: [0])`, capturada
/// de una corrida real (práctica golden estándar) y pegada verbatim. Fija:
/// levelId derivado, claves del wire contract, paintRole por flecha, palette
/// top-level, y la AUSENCIA de `order`/`timeLimitSec` (temático v1 sin límite).
const _goldenJson = '''
{
  "levelId": "themed-mini",
  "cols": 6,
  "rows": 4,
  "arrows": [
    {
      "id": "arrow-0",
      "headDir": "right",
      "cells": [
        [
          0,
          1
        ],
        [
          1,
          1
        ],
        [
          1,
          2
        ]
      ],
      "paintRole": "alpha"
    },
    {
      "id": "arrow-1",
      "headDir": "down",
      "cells": [
        [
          0,
          0
        ],
        [
          1,
          0
        ]
      ],
      "paintRole": "alpha"
    },
    {
      "id": "arrow-2",
      "headDir": "right",
      "cells": [
        [
          3,
          3
        ],
        [
          3,
          4
        ]
      ],
      "paintRole": "beta"
    },
    {
      "id": "arrow-3",
      "headDir": "left",
      "cells": [
        [
          3,
          5
        ],
        [
          2,
          5
        ],
        [
          2,
          4
        ]
      ],
      "paintRole": "beta"
    }
  ],
  "palette": {
    "alpha": "#FF0000",
    "beta": "#0000FF"
  }
}
''';

void main() {
  group('produceThemed — golden de la máscara mini', () {
    test('con la semilla fija 0 el JSON es byte-idéntico al golden', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);

      // Assert
      expect(result.json, _goldenJson);
      expect(result.levelId, 'themed-mini');
      expect(result.seedUsed, 0);
    });

    test('el golden NO lleva order ni timeLimitSec (temático v1 sin límite)',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final map =
          jsonDecode(produceThemed(mask, seeds: const [0]).json)
              as Map<String, dynamic>;

      // Assert: la ausencia de timeLimitSec ES la anotación de "sin límite".
      expect(map.containsKey('order'), isFalse);
      expect(map.containsKey('timeLimitSec'), isFalse);
    });
  });

  group('produceThemed — paintRole y palette', () {
    test('cada paintRole emitido es clave de la palette y palette == mask.palette',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);
      final map = jsonDecode(result.json) as Map<String, dynamic>;

      // Assert
      final palette =
          (map['palette'] as Map<String, dynamic>).cast<String, String>();
      expect(palette, mask.palette);
      final arrows = map['arrows'] as List<dynamic>;
      expect(arrows, isNotEmpty);
      for (final arrow in arrows.cast<Map<String, dynamic>>()) {
        expect(palette.keys, contains(arrow['paintRole']));
      }
    });
  });

  group('produceThemed — contabilidad de cobertura', () {
    test('coveragePerRole tiene los roles de la máscara y valores en [0,1]',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);

      // Assert
      expect(result.coveragePerRole.keys.toSet(),
          mask.regions.map((r) => r.role).toSet());
      for (final value in result.coveragePerRole.values) {
        expect(value, inInclusiveRange(0, 1));
      }
    });

    test('para la semilla golden la cobertura coincide con covered/total '
        'recomputado desde las flechas del JSON', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);
      final result = produceThemed(mask, seeds: const [0]);
      final map = jsonDecode(result.json) as Map<String, dynamic>;

      // Act: recomputar cobertura a mano desde el JSON decodificado.
      final occupiedByRole = <String, Set<Position>>{};
      for (final arrow
          in (map['arrows'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final role = arrow['paintRole'] as String;
        final cells = occupiedByRole.putIfAbsent(role, () => <Position>{});
        for (final cell in (arrow['cells'] as List<dynamic>)) {
          final pair = (cell as List<dynamic>).cast<int>();
          cells.add(Position(row: pair[0], col: pair[1]));
        }
      }

      // Assert
      for (final region in mask.regions) {
        final covered = region.cells
            .where((c) => occupiedByRole[region.role]?.contains(c) ?? false)
            .length;
        expect(result.coveragePerRole[region.role],
            covered / region.cells.length);
      }
    });
  });

  group('produceThemed — solubilidad y determinismo', () {
    test('producir no lanza y coloca al menos una flecha', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);

      // Assert: produceThemed valida internamente (vaciado en orden inverso);
      // llegar aquí sin excepción ya certifica la solubilidad del nivel.
      expect(result.placedArrows, greaterThan(0));
    });

    test('misma máscara + mismas semillas ⇒ JSON idéntico', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);
      const seeds = [0, 1, 2, 3, 4];

      // Act
      final a = produceThemed(mask, seeds: seeds);
      final b = produceThemed(mask, seeds: seeds);

      // Assert
      expect(a.json, b.json);
      expect(a.seedUsed, b.seedUsed);
      expect(a.coveragePerRole, b.coveragePerRole);
    });
  });
}
