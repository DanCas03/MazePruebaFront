/// Política de dificultad (dominio puro): mapea un número de nivel a las
/// dimensiones del tablero y la cantidad de flechas. Concentra TODA la curva en
/// un solo lugar testeable; el generador solo genera, no decide dificultad.
class LevelBlueprint {
  /// Nivel a partir del cual los tableros llevan límite de tiempo (ADR 0001,
  /// decisión 6: "límite de tiempo opcional en niveles avanzados").
  static const int timedFromLevel = 6;

  final int cols;
  final int rows;
  final int arrowCount;
  final int maxPathLen;

  /// Segundos de cuenta atrás del nivel, o `null` si no tiene límite. Al
  /// agotarse, la partida transiciona a `GameLost` (reloj inyectable, front#11).
  final int? timeLimitSec;

  const LevelBlueprint({
    required this.cols,
    required this.rows,
    required this.arrowCount,
    required this.maxPathLen,
    this.timeLimitSec,
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
    // Niveles avanzados (>= timedFromLevel) añaden presión temporal: 90 s que
    // se reducen 5 s por nivel, con piso de 30 s. Los previos no tienen límite.
    final timeLimitSec = lvl < timedFromLevel
        ? null
        : (90 - (lvl - timedFromLevel) * 5).clamp(30, 90);
    return LevelBlueprint(
      cols: width,
      rows: height,
      arrowCount: arrowCount,
      maxPathLen: maxPathLen,
      timeLimitSec: timeLimitSec,
    );
  }
}
