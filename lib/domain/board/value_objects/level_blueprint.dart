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

  /// Curva inicial: tablero cuadrado que crece de 4 a 9 con el nivel, relleno
  /// ~50 % con flechas de largo medio ~3. Ajustable sin tocar generador ni UI.
  factory LevelBlueprint.forLevel(int level) {
    final lvl = level < 1 ? 1 : level;
    final size = (4 + (lvl - 1) ~/ 2).clamp(4, 9);
    final arrowCount = ((size * size * 0.5) / 3).round().clamp(4, size * size);
    // maxPathLen crece con el nivel: niveles bajos tienen flechas más cortas.
    final maxPathLen = (2 + (lvl - 1) ~/ 3).clamp(2, 6);
    return LevelBlueprint(
        cols: size, rows: size, arrowCount: arrowCount, maxPathLen: maxPathLen);
  }
}
