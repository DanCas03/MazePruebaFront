/// Política de dificultad (dominio puro): mapea un número de nivel a las
/// dimensiones del tablero y la cantidad de flechas. Concentra TODA la curva en
/// un solo lugar testeable; el generador solo genera, no decide dificultad.
class LevelBlueprint {
  final int cols;
  final int rows;
  final int arrowCount;
  final int maxPathLen;

  const LevelBlueprint({
    required this.cols,
    required this.rows,
    required this.arrowCount,
    required this.maxPathLen,
  });

  /// Curva vertical-densa: tablero más alto que ancho que crece ~6x8 → ~11x15,
  /// relleno ~68 % con caminos doblados cuyo largo máximo crece de 3 a 12.
  factory LevelBlueprint.forLevel(int level) {
    final lvl = level < 1 ? 1 : level;
    final width = (6 + (lvl - 1) ~/ 3).clamp(6, 11);
    final height = (8 + (lvl - 1) ~/ 2).clamp(8, 15);
    final maxPathLen = (3 + (lvl - 1) ~/ 2).clamp(3, 12);
    final avgPathLen = (2 + maxPathLen) / 2;
    final arrowCount = (width * height * 0.68 / avgPathLen)
        .round()
        .clamp(4, width * height);
    return LevelBlueprint(
      cols: width,
      rows: height,
      arrowCount: arrowCount,
      maxPathLen: maxPathLen,
    );
  }
}
