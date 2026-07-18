import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

/// Golden de caracterización (front#124): congela la salida de
/// [GraphBoardGenerator.generate] ANTES de migrar `Direction.values` →
/// `space.directions`, para garantizar que la migración es byte-idéntica.
///
/// Patrón captura-en-primera-corrida: si el fixture no existe lo escribe y
/// FALLA pidiendo revisar/commitear; si existe, asevera igualdad exacta. La
/// captura se hace sobre el código ACTUAL (4 direcciones); tras la migración
/// este mismo test debe seguir verde sin regenerar nada.
void main() {
  final generator = GraphBoardGenerator();
  const encoder = LevelJsonEncoder();

  final cases = <({
    String id,
    int cols,
    int rows,
    int arrowCount,
    int maxPathLen,
    int seed,
  })>[
    (id: 'campaign-8x11-a9-p5-s302', cols: 8, rows: 11, arrowCount: 9, maxPathLen: 5, seed: 302),
    (id: 'campaign-6x8-a6-p4-s1', cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 1),
    (id: 'campaign-10x10-a12-p6-s77', cols: 10, rows: 10, arrowCount: 12, maxPathLen: 6, seed: 77),
  ];

  group('GraphBoardGenerator.generate — golden byte-idéntico (front#124)', () {
    for (final c in cases) {
      test('should_match_frozen_golden_${c.id}', () {
        // Arrange
        final board = generator.generate(
          cols: c.cols,
          rows: c.rows,
          arrowCount: c.arrowCount,
          maxPathLen: c.maxPathLen,
          seed: c.seed,
        );
        final json = encoder.encode(levelId: c.id, board: board);
        final file =
            File('test/infrastructure/generators/golden/${c.id}.json');

        // Act + Assert
        if (!file.existsSync()) {
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(json);
          fail('Golden capturado en ${file.path}. Revísalo y vuelve a correr.');
        }
        expect(json, equals(file.readAsStringSync()));
      });
    }
  });
}
