import 'dart:math';

import '../../domain/game_core/value_objects/position.dart';

/// Bandas concéntricas de un rectángulo cols×rows, de la MÁS INTERIOR
/// (índice 0) a la más exterior. Distancia al borde
/// d = min(row, col, rows-1-row, cols-1-col); el rango [0..maxD] se divide
/// en k = min(3, maxD + 1) bandas de ancho igual. Tableros pequeños
/// degeneran a 1–2 bandas. Toda celda cae exactamente en una banda.
List<List<Position>> concentricBands({required int cols, required int rows}) {
  final maxD = (min(rows, cols) - 1) ~/ 2;
  final k = min(3, maxD + 1);
  final bands = List.generate(k, (_) => <Position>[]);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final d = [r, c, rows - 1 - r, cols - 1 - c].reduce(min);
      final band = ((maxD - d) * k) ~/ (maxD + 1); // 0 = interior (d alto)
      bands[band].add(Position(row: r, col: c));
    }
  }
  return bands;
}

/// Reparto por mayor resto: cuotas ∝ sizes, suma exacta = total.
List<int> largestRemainderQuotas(int total, List<int> sizes) {
  final sum = sizes.fold<int>(0, (a, b) => a + b);
  if (sum == 0) return List.filled(sizes.length, 0);
  final exact = [for (final s in sizes) total * s / sum];
  final quotas = [for (final e in exact) e.floor()];
  var remaining = total - quotas.fold<int>(0, (a, b) => a + b);
  final order = List.generate(sizes.length, (i) => i)
    ..sort((a, b) => (exact[b] - quotas[b]).compareTo(exact[a] - quotas[a]));
  for (final i in order) {
    if (remaining == 0) break;
    quotas[i]++;
    remaining--;
  }
  return quotas;
}
