// tool/generate_level_candidates.dart
//
// E2.1 (front#1): corre GraphBoardGenerator con una tabla FIJA de seeds y
// congela candidatos de nivel como JSON arrow-path wire-estricto, insumo de
// la curación E2.2 (elegir 3 por tier => 15 niveles). Sin argumentos produce
// SIEMPRE el mismo set completo; la reproducibilidad vive en esta tabla
// versionada, y el artefacto congelado real son los JSON commiteados
// (Random(seed) de Dart no garantiza estabilidad entre versiones del SDK).
//
// Uso: dart run tool/generate_level_candidates.dart [--out <dir>]
import 'dart:io';

import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

class CandidateSpec {
  final int tier;
  final int cols;
  final int rows;
  final int arrowCount;
  final int maxPathLen;
  final int seed;

  const CandidateSpec({
    required this.tier,
    required this.cols,
    required this.rows,
    required this.arrowCount,
    required this.maxPathLen,
    required this.seed,
  });

  /// Identidad trazable del candidato: tier + seed bastan para reproducirlo.
  String get levelId => 'cand-t$tier-s$seed';
}

// Rampa de dificultad: 5 tiers x 6 candidatos = 30 (2x oversupply: la
// curacion elige 3 por tier). Dims en vertical (cols < rows, como el wire).
const _batchSpec = <CandidateSpec>[
  // Tier 1 — 6x8, maxPathLen 4
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 101),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 102),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 103),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 104),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 105),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 106),
  // Tier 2 — 7x10, maxPathLen 5
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 7, maxPathLen: 5, seed: 201),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 7, maxPathLen: 5, seed: 202),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 7, maxPathLen: 5, seed: 203),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 8, maxPathLen: 5, seed: 204),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 8, maxPathLen: 5, seed: 205),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 8, maxPathLen: 5, seed: 206),
  // Tier 3 — 8x11, maxPathLen 5
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 9, maxPathLen: 5, seed: 301),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 9, maxPathLen: 5, seed: 302),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 10, maxPathLen: 5, seed: 303),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 10, maxPathLen: 5, seed: 304),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 11, maxPathLen: 5, seed: 305),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 11, maxPathLen: 5, seed: 306),
  // Tier 4 — 9x13, maxPathLen 6
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 12, maxPathLen: 6, seed: 401),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 12, maxPathLen: 6, seed: 402),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 13, maxPathLen: 6, seed: 403),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 13, maxPathLen: 6, seed: 404),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 14, maxPathLen: 6, seed: 405),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 14, maxPathLen: 6, seed: 406),
  // Tier 5 — 11x15, maxPathLen 7
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 15, maxPathLen: 7, seed: 501),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 15, maxPathLen: 7, seed: 502),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 16, maxPathLen: 7, seed: 503),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 16, maxPathLen: 7, seed: 504),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 18, maxPathLen: 7, seed: 505),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 18, maxPathLen: 7, seed: 506),
];

const _manifestHeader = '''
# Candidatos de nivel — batch v1

Generado por `dart run tool/generate_level_candidates.dart` (tabla fija de seeds).
Insumo de la curación E2.2: elegir 3 por tier => 15 niveles (ver CONTEXT-MAP, wire contract).
NO editar a mano: regenerar con el script (misma tabla => mismos bytes).
`(!)` = degradación con gracia: el generador coloco menos flechas de las pedidas.

| candidato | dims (cols x rows) | flechas (colocadas/pedidas) | maxPathLen | seed |
|---|---|---|---|---|
''';

void main(List<String> args) {
  final outPath = _parseOut(args) ?? 'tool/candidates';
  final outDir = Directory(outPath)..createSync(recursive: true);

  final generator = GraphBoardGenerator();
  const encoder = LevelJsonEncoder();
  final manifest = StringBuffer(_manifestHeader);
  var degraded = 0;

  for (final spec in _batchSpec) {
    final board = generator.generate(
      cols: spec.cols,
      rows: spec.rows,
      arrowCount: spec.arrowCount,
      maxPathLen: spec.maxPathLen,
      seed: spec.seed,
    );
    File('${outDir.path}/${spec.levelId}.json')
        .writeAsStringSync(encoder.encode(levelId: spec.levelId, board: board));

    final placed = board.arrows.length;
    final flag = placed < spec.arrowCount ? ' (!)' : '';
    if (placed < spec.arrowCount) degraded++;
    manifest.writeln(
        '| ${spec.levelId} | ${spec.cols}x${spec.rows} | $placed/${spec.arrowCount}$flag | ${spec.maxPathLen} | ${spec.seed} |');
  }

  File('${outDir.path}/manifest.md').writeAsStringSync(manifest.toString());
  stdout.writeln(
      'Exported ${_batchSpec.length} candidates to ${outDir.path} ($degraded degraded).');
}

String? _parseOut(List<String> args) {
  final i = args.indexOf('--out');
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
