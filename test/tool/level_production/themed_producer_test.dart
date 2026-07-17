import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_decoder.dart';

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

/// GOLDEN: salida byte-estable de `produceThemed(mini)` (determinista desde
/// front#114: `generateThemedFull`, sin semillas), capturada de una corrida
/// real (práctica golden estándar) y pegada verbatim. Fija: levelId derivado,
/// claves del wire contract, paintRole por flecha, cobertura TOTAL de la
/// figura (flechas rectas ≥2), palette top-level, y la AUSENCIA de
/// `order`/`timeLimitSec` (temático v1 sin límite).
const _goldenJson = '''
{
  "levelId": "themed-mini",
  "cols": 6,
  "rows": 4,
  "arrows": [
    {
      "id": "arrow-0",
      "headDir": "left",
      "cells": [
        [
          3,
          5
        ],
        [
          3,
          4
        ],
        [
          3,
          3
        ]
      ],
      "paintRole": "beta"
    },
    {
      "id": "arrow-1",
      "headDir": "left",
      "cells": [
        [
          2,
          5
        ],
        [
          2,
          4
        ],
        [
          2,
          3
        ]
      ],
      "paintRole": "beta"
    },
    {
      "id": "arrow-2",
      "headDir": "left",
      "cells": [
        [
          1,
          2
        ],
        [
          1,
          1
        ],
        [
          1,
          0
        ]
      ],
      "paintRole": "alpha"
    },
    {
      "id": "arrow-3",
      "headDir": "left",
      "cells": [
        [
          0,
          2
        ],
        [
          0,
          1
        ],
        [
          0,
          0
        ]
      ],
      "paintRole": "alpha"
    }
  ],
  "palette": {
    "alpha": "#FF0000",
    "beta": "#0000FF"
  },
  "silhouette": {
    "alpha": [
      [
        0,
        0
      ],
      [
        0,
        1
      ],
      [
        0,
        2
      ],
      [
        1,
        0
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
    "beta": [
      [
        2,
        3
      ],
      [
        2,
        4
      ],
      [
        2,
        5
      ],
      [
        3,
        3
      ],
      [
        3,
        4
      ],
      [
        3,
        5
      ]
    ]
  }
}
''';

void main() {
  group('produceThemed — golden de la máscara mini', () {
    test('el JSON es byte-idéntico al golden (determinista, seeds ignoradas)',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act — seeds se pasa por compatibilidad de firma; se ignora (front#114).
      final result = produceThemed(mask, seeds: const [0]);

      // Assert
      expect(result.json, _goldenJson);
      expect(result.levelId, 'themed-mini');
      // seedUsed es siempre 0 desde front#114 (sin rng ni búsqueda de semillas).
      expect(result.seedUsed, 0);
    });

    test('el golden cubre la figura al 100% con flechas rectas de >= 2 celdas',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);
      final map = jsonDecode(result.json) as Map<String, dynamic>;

      // Assert — cobertura total por región (generateThemedFull) y ninguna
      // flecha degenerada de 1 celda.
      expect(result.allRegionsMetTarget, isTrue);
      for (final value in result.coveragePerRole.values) {
        expect(value, 1.0);
      }
      for (final arrow
          in (map['arrows'] as List<dynamic>).cast<Map<String, dynamic>>()) {
        expect((arrow['cells'] as List<dynamic>).length,
            greaterThanOrEqualTo(2));
      }
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

  group('produceThemed — silueta', () {
    test('emite silhouette con TODAS las celdas de cada región de la máscara',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);
      final level = const LevelJsonDecoder()
          .decode(jsonDecode(result.json) as Map<String, Object?>);

      // Assert: cada rol lleva EXACTAMENTE las celdas de su región (relleno
      // visual completo), independientemente de qué celdas ocupan las flechas.
      for (final region in mask.regions) {
        expect(level.silhouette![region.role]!.toSet(), region.cells);
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

    test('la cobertura coincide con covered/total recomputado desde las '
        'flechas del JSON', () {
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

    test('misma máscara ⇒ JSON idéntico incluso con semillas DISTINTAS '
        '(seeds se ignora: generación determinista sin rng)', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act — semillas distintas a propósito: no deben influir en la salida.
      final a = produceThemed(mask, seeds: const [0, 1, 2, 3, 4]);
      final b = produceThemed(mask, seeds: const [99, 1234]);

      // Assert
      expect(a.json, b.json);
      expect(a.seedUsed, b.seedUsed);
      expect(a.coveragePerRole, b.coveragePerRole);
    });
  });

  group('produceThemed — regiones interiores encerradas', () {
    test('una región interior encerrada recibe flechas (no queda en 0%)', () {
      // Arrange — 'inner' (2x2) queda totalmente rodeada por 'outer'.
      // generateThemedFull pela la figura celda a celda (las flechas salen en
      // orden inverso a la colocación), así que las regiones interiores se
      // cubren igual que las exteriores.
      const enclosed = '''
name: enclosed
legend:
  O = outer : #FFFFFF
  I = inner : #FF0000
grid:
OOOOOOO
OOOOOOO
OOOOOOO
OOOIIOO
OOOIIOO
OOOOOOO
OOOOOOO
''';
      final mask = parseMaskSpec(enclosed);

      // Act
      final result = produceThemed(
        mask,
        seeds: List<int>.generate(30, (i) => i),
        maxPathLen: 3,
      );

      // Assert — la región interior recibe al menos una flecha.
      expect(result.coveragePerRole['inner'], greaterThan(0.0));
    });
  });
}
