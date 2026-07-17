import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_decoder.dart';

import '../../../tool/level_production/mask_spec.dart';
import '../../../tool/level_production/themed_producer.dart';

/// Máscara mini de 2 regiones (6×4) usada por los tests LEGACY (dense: false):
/// pequeña, determinista y con dos roles/colores distintos.
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

/// Máscara mini para el modo DENSO: regiones de tamaño DISTINTO (12 vs 15
/// celdas) para que la región de detalle (la menor, `alpha`) sea determinista.
const _miniDenseMask = '''
name: minidense
legend:
  A = alpha : #FF0000
  B = beta : #0000FF
grid:
AAAA....
AAAA....
AAAA....
...BBBBB
...BBBBB
...BBBBB
''';

/// GOLDEN (legacy, `dense: false`): salida byte-estable de
/// `produceThemed(mini, seeds: [0], dense: false)`, capturada de una corrida
/// real (práctica golden estándar) y pegada verbatim. Fija: levelId derivado,
/// claves del wire contract, paintRole por flecha, palette top-level, la
/// AUSENCIA de `order`/`timeLimitSec` (temático v1 sin límite) y — desde #118 —
/// la `silhouette` (fill COMPLETO de las regiones de la máscara, row-major).
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
  group('produceThemed (legacy) — golden de la máscara mini', () {
    test('con la semilla fija 0 el JSON es byte-idéntico al golden', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0], dense: false);

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
          jsonDecode(produceThemed(mask, seeds: const [0], dense: false).json)
              as Map<String, dynamic>;

      // Assert: la ausencia de timeLimitSec ES la anotación de "sin límite".
      expect(map.containsKey('order'), isFalse);
      expect(map.containsKey('timeLimitSec'), isFalse);
    });
  });

  group('produceThemed (legacy) — paintRole y palette', () {
    test('cada paintRole emitido es clave de la palette y palette == mask.palette',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0], dense: false);
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

  group('produceThemed (legacy) — contabilidad de cobertura', () {
    test('coveragePerRole tiene los roles de la máscara y valores en [0,1]',
        () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0], dense: false);

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
      final result = produceThemed(mask, seeds: const [0], dense: false);
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

  group('produceThemed (legacy) — solubilidad y determinismo', () {
    test('producir no lanza y coloca al menos una flecha', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);

      // Act
      final result = produceThemed(mask, seeds: const [0], dense: false);

      // Assert: produceThemed valida internamente (vaciado en orden inverso);
      // llegar aquí sin excepción ya certifica la solubilidad del nivel.
      expect(result.placedArrows, greaterThan(0));
    });

    test('misma máscara + mismas semillas ⇒ JSON idéntico', () {
      // Arrange
      final mask = parseMaskSpec(_miniMask);
      const seeds = [0, 1, 2, 3, 4];

      // Act
      final a = produceThemed(mask, seeds: seeds, dense: false);
      final b = produceThemed(mask, seeds: seeds, dense: false);

      // Assert
      expect(a.json, b.json);
      expect(a.seedUsed, b.seedUsed);
      expect(a.coveragePerRole, b.coveragePerRole);
    });
  });

  group('produceThemed (legacy) — orden detalle-primero', () {
    test('una región interior encerrada recibe flechas (no queda en 0%)', () {
      // Arrange — 'inner' (2x2) queda totalmente rodeada por 'outer': cada lane
      // de salida de sus celdas cruza la región exterior. Si 'outer' se llenara
      // primero, 'inner' no encontraría lane libre y quedaría en 0%.
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
        dense: false,
      );

      // Assert — el orden detalle-primero coloca 'inner' sobre el tablero vacío,
      // así que recibe al menos una flecha.
      expect(result.coveragePerRole['inner'], greaterThan(0.0));
    });
  });

  group('selectDenseSeed — criterio de selección congelado (#118)', () {
    // El criterio es lexicográfico y NO por cobertura sola (heart: la seed de
    // mayor cobertura dejaba dos celdas libres a profundidad 3-4 en mitad de
    // la figura). Prioridad: 1) detalle lleno, 2) maxDepth <= 2, 3) mayor
    // cobertura; empate → la primera vista (seed más baja).
    test('detalle lleno gana a mayor cobertura', () {
      // Arrange
      const metrics = [
        DenseSeedMetrics(
            seed: 0, coverage: 0.99, maxHoleDepth: 0, detailFull: false),
        DenseSeedMetrics(
            seed: 1, coverage: 0.95, maxHoleDepth: 0, detailFull: true),
      ];

      // Act
      final chosen = selectDenseSeed(metrics);

      // Assert
      expect(chosen?.seed, 1);
    });

    test('maxDepth <= 2 gana a mayor cobertura (sin bolsillos interiores)',
        () {
      // Arrange
      const metrics = [
        DenseSeedMetrics(
            seed: 0, coverage: 0.99, maxHoleDepth: 4, detailFull: true),
        DenseSeedMetrics(
            seed: 1, coverage: 0.95, maxHoleDepth: 2, detailFull: true),
      ];

      // Act
      final chosen = selectDenseSeed(metrics);

      // Assert
      expect(chosen?.seed, 1);
    });

    test('entre admisibles gana la mayor cobertura; empate → seed más baja',
        () {
      // Arrange
      const metrics = [
        DenseSeedMetrics(
            seed: 0, coverage: 0.95, maxHoleDepth: 0, detailFull: true),
        DenseSeedMetrics(
            seed: 1, coverage: 0.97, maxHoleDepth: 1, detailFull: true),
        DenseSeedMetrics(
            seed: 2, coverage: 0.97, maxHoleDepth: 2, detailFull: true),
      ];

      // Act
      final chosen = selectDenseSeed(metrics);

      // Assert
      expect(chosen?.seed, 1);
    });

    test('sin admisibles devuelve null (rojo ruidoso aguas arriba, nunca '
        'degradarse a "la de más cobertura")', () {
      // Arrange
      const metrics = [
        DenseSeedMetrics(
            seed: 0, coverage: 0.99, maxHoleDepth: 3, detailFull: true),
        DenseSeedMetrics(
            seed: 1, coverage: 0.99, maxHoleDepth: 0, detailFull: false),
      ];

      // Act + Assert
      expect(selectDenseSeed(metrics), isNull);
    });
  });

  group('produceThemed — modo denso (#118)', () {
    test('emite silhouette == fill COMPLETO de las regiones de la máscara '
        '(no la unión de flechas)', () {
      // Arrange
      final mask = parseMaskSpec(_miniDenseMask);

      // Act
      final result = produceThemed(mask, seeds: const [0]);
      final map = jsonDecode(result.json) as Map<String, dynamic>;

      // Assert
      final silhouette = map['silhouette'] as Map<String, dynamic>;
      expect(silhouette.keys.toSet(),
          mask.regions.map((r) => r.role).toSet());
      for (final region in mask.regions) {
        final cells = {
          for (final cell in silhouette[region.role] as List<dynamic>)
            Position(
                row: (cell as List<dynamic>)[0] as int, col: cell[1] as int),
        };
        expect(cells, region.cells,
            reason: 'la silueta de "${region.role}" debe ser el fill completo '
                'de la región de la máscara');
      }
    });

    test('el JSON denso decodifica a un Level válido con silueta '
        '(invariante flechas ⊆ silueta)', () {
      // Arrange
      final mask = parseMaskSpec(_miniDenseMask);
      final result = produceThemed(mask, seeds: const [0]);

      // Act — el constructor de Level EXIGE flechas ⊆ silhouetteUnion; decodear
      // sin excepción certifica la invariante.
      final level = const LevelJsonDecoder()
          .decode(jsonDecode(result.json) as Map<String, Object?>);

      // Assert
      expect(level.silhouette, isNotNull);
      expect(level.silhouette!.keys.toSet(),
          mask.regions.map((r) => r.role).toSet());
    });

    test('lanza StateError cuando ninguna seed cumple el criterio '
        '(happy_face seed 0 deja `features` incompleta)', () {
      // Arrange — medido en el barrido 0..99: seed 0 tiene features
      // incompletas y maxDepth 3, así que NO es admisible.
      final mask = parseMaskSpec(
          File('tool/level_production/masks/happy_face.mask')
              .readAsStringSync());

      // Act + Assert
      expect(() => produceThemed(mask, seeds: const [0]),
          throwsA(isA<StateError>()));
    });

    test('heart con el lote 0..99 aterriza en la seed 67 de los guardianes '
        '(cobertura 0.9885, maxDepth 0) y cubre >= 0.90', () {
      // Arrange
      final mask = parseMaskSpec(
          File('tool/level_production/masks/heart.mask').readAsStringSync());
      final seeds = List<int>.generate(100, (i) => i);

      // Act
      final result = produceThemed(mask, seeds: seeds);

      // Assert — misma seed que eligen los guardianes de
      // graph_board_themed_dense_test.dart con el criterio congelado.
      expect(result.seedUsed, 67);
      expect(result.allRegionsMetTarget, isTrue);
      for (final entry in result.coveragePerRole.entries) {
        expect(entry.value, greaterThanOrEqualTo(0.90),
            reason: 'región ${entry.key}');
      }
    });

    test('happy_face con el lote 0..99 aterriza en la seed 41 de los '
        'guardianes (features 64/64) y cubre >= 0.90 en ambas regiones', () {
      // Arrange
      final mask = parseMaskSpec(
          File('tool/level_production/masks/happy_face.mask')
              .readAsStringSync());
      final seeds = List<int>.generate(100, (i) => i);

      // Act
      final result = produceThemed(mask, seeds: seeds);

      // Assert
      expect(result.seedUsed, 41);
      expect(result.allRegionsMetTarget, isTrue);
      expect(result.coveragePerRole['features'], 1.0,
          reason: 'la región de detalle debe quedar al 100% (criterio 1)');
      for (final entry in result.coveragePerRole.entries) {
        expect(entry.value, greaterThanOrEqualTo(0.90),
            reason: 'región ${entry.key}');
      }
    });
  });
}
