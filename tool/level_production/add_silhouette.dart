// tool/level_production/add_silhouette.dart
//
// One-off (#118): añade la clave `silhouette` al conejo CONGELADO
// (`themed-bunny.json`) SIN regenerarlo. El conejo es el benchmark estético
// del maintainer: sus 37 flechas, su máscara 16×20 y su palette quedan
// byte-idénticas — solo GANA la silueta, derivada de `bunny.mask` (el fill
// COMPLETO de cada región, no la unión de flechas).
//
// Uso:
//   dart run tool/level_production/add_silhouette.dart
//
// Salvaguardas: el script decodifica el fixture, lo re-encodea con la silueta
// y ABORTA si el bloque `arrows` (o `palette`) cambió en algo, o si el
// resultado no decodifica a un Level válido (invariante flechas ⊆ silueta).
// Idempotente: re-ejecutarlo sobre un fixture que ya lleva silueta reproduce
// los mismos bytes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_decoder.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

import 'mask_spec.dart';

const _fixturePath = 'tool/level_production/themed/themed-bunny.json';
const _maskPath = 'tool/level_production/masks/bunny.mask';

void main() {
  final raw = File(_fixturePath).readAsStringSync();
  final rawMap = jsonDecode(raw) as Map<String, Object?>;
  final level = const LevelJsonDecoder().decode(rawMap);

  final mask = parseMaskSpec(File(_maskPath).readAsStringSync());
  final silhouette = <String, Set<Position>>{
    for (final region in mask.regions) region.role: region.cells,
  };

  final updated = const LevelJsonEncoder().encode(
    levelId: level.id.value,
    board: level.board,
    palette: level.palette,
    silhouette: silhouette,
  );
  final updatedMap = jsonDecode(updated) as Map<String, Object?>;

  // Salvaguarda 1: las flechas y la palette del conejo son intocables.
  if (jsonEncode(rawMap['arrows']) != jsonEncode(updatedMap['arrows'])) {
    throw StateError('las flechas del conejo cambiaron — abortado sin escribir');
  }
  if (jsonEncode(rawMap['palette']) != jsonEncode(updatedMap['palette'])) {
    throw StateError('la palette del conejo cambió — abortado sin escribir');
  }

  // Salvaguarda 2: el resultado decodifica a un Level válido (el constructor
  // de Level EXIGE flechas ⊆ silhouetteUnion).
  const LevelJsonDecoder().decode(updatedMap);

  File(_fixturePath).writeAsStringSync(updated);
  stdout.writeln('✓ $_fixturePath: silhouette añadida '
      '(${mask.regions.map((r) => '${r.role}:${r.cells.length}').join(' ')}), '
      '${level.board.arrows.length} flechas intactas');
}
