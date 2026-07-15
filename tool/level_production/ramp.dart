// tool/level_production/ramp.dart
//
// Rampa de producción (front#65). Traduce un tier de la campaña a los
// parámetros con los que el generador debe producir sus candidatos: dimensiones
// del tablero, densidad de relleno, largo máximo de camino doblado y (para los
// tiers avanzados) un presupuesto de tiempo derivado.
//
// Es el ÚNICO lugar donde vive la curva de dificultad de PRODUCCIÓN — el
// sucesor del retirado `LevelBlueprint`. No confundir con `Difficulty` (dominio,
// front#36): aquel es el preset que elige el jugador para un `GeneratedBoard`
// efímero; esta Rampa es la política de la campaña oficial (15 niveles · 5 tiers
// × 3, culminando en un 50×50), material de curación humana.
//
// La campaña conserva su estructura 15 = 5 tiers × 3. El tier 5 tiene DOS
// perfiles: los niveles 13–14 (42×46) y el remate nivel 15 (50×50), que se pide
// con `finale: true`.

/// Un escalón de la rampa: los parámetros de generación de un tier (o del
/// remate). `arrowCount` y `timeLimitSec` se DERIVAN de estos campos con la
/// misma fórmula de densidad que la campaña; el productor no elige números.
class RampStep {
  /// Tier de la campaña (1–5) al que pertenece el candidato. Determina el
  /// prefijo trazable del id: `cand-t<tier>-s<seed>`.
  final int tier;

  /// true ⇒ es el remate de la campaña (nivel 15, 50×50), no los niveles
  /// regulares del tier 5. Solo el tier 5 admite remate.
  final bool finale;

  /// Dimensiones del tablero (vertical: `cols <= rows`, como el wire contract).
  final int cols;
  final int rows;

  /// Fracción de celdas que los cuerpos de flecha buscan ocupar (densidad).
  final double fillRatio;

  /// Largo máximo (en celdas) de los caminos doblados que coloca el generador.
  final int maxPathLen;

  /// true ⇒ los candidatos llevan cuenta atrás derivada (ver [timeLimitSec]).
  /// Los tiers 1–2 son sin límite; del tier 3 en adelante, con límite.
  final bool timed;

  const RampStep({
    required this.tier,
    required this.finale,
    required this.cols,
    required this.rows,
    required this.fillRatio,
    required this.maxPathLen,
    required this.timed,
  });

  /// Piso mínimo de flechas para que el resultado sea un puzzle (mismo piso que
  /// la campaña). El techo teórico es (celdas ~/ 2): cada flecha ocupa >= 2.
  static const int minArrowCount = 4;

  /// Cantidad de flechas objetivo, derivada de la densidad del escalón. Misma
  /// fórmula que la campaña: celdas objetivo / largo medio de camino, con el
  /// largo medio estimado como (2 + maxPathLen) / 2.
  int get arrowCount {
    final avgPathLen = (2 + maxPathLen) / 2;
    return (cols * rows * fillRatio / avgPathLen)
        .round()
        .clamp(minArrowCount, (cols * rows) ~/ 2);
  }

  /// Cuenta atrás derivada, en segundos, o `null` si el escalón es sin límite.
  /// Fórmula de la campaña (front#65): `arrowCount × 4`, redondeada HACIA ARRIBA
  /// al múltiplo de 30 más cercano — timers "redondos" y proporcionales a la
  /// carga de flechas, no al tamaño crudo del tablero.
  int? get timeLimitSec {
    if (!timed) return null;
    final raw = arrowCount * 4;
    return ((raw + 29) ~/ 30) * 30; // ceil al múltiplo de 30
  }
}

/// Tabla canónica de la rampa. Seis escalones: los cinco tiers regulares más el
/// remate 50×50 del tier 5 (nivel 15). Ordenada por dificultad creciente.
const List<RampStep> rampTable = [
  // T1 (niveles 1–3) — 6×8, sin límite.
  RampStep(tier: 1, finale: false, cols: 6, rows: 8, fillRatio: 0.30, maxPathLen: 3, timed: false),
  // T2 (niveles 4–6) — 10×12, sin límite.
  RampStep(tier: 2, finale: false, cols: 10, rows: 12, fillRatio: 0.38, maxPathLen: 5, timed: false),
  // T3 (niveles 7–9) — 18×20, con límite derivado.
  RampStep(tier: 3, finale: false, cols: 18, rows: 20, fillRatio: 0.45, maxPathLen: 7, timed: true),
  // T4 (niveles 10–12) — 30×34, con límite derivado.
  RampStep(tier: 4, finale: false, cols: 30, rows: 34, fillRatio: 0.55, maxPathLen: 10, timed: true),
  // T5 (niveles 13–14) — 42×46, con límite derivado.
  RampStep(tier: 5, finale: false, cols: 42, rows: 46, fillRatio: 0.60, maxPathLen: 12, timed: true),
  // T5 (nivel 15, remate) — 50×50, con límite derivado.
  RampStep(tier: 5, finale: true, cols: 50, rows: 50, fillRatio: 0.65, maxPathLen: 12, timed: true),
];

/// Tier mínimo/máximo aceptados por la rampa (útil para validar CLI args).
const int minTier = 1;
const int maxTier = 5;

/// El escalón de la rampa para [tier], o su remate 50×50 si [finale] es true.
/// Lanza [ArgumentError] si el tier está fuera de rango, o si se pide remate
/// para un tier que no sea el 5 (solo la campaña remata en el tier 5).
RampStep rampStepFor(int tier, {bool finale = false}) {
  if (tier < minTier || tier > maxTier) {
    throw ArgumentError.value(tier, 'tier', 'must be between $minTier and $maxTier');
  }
  if (finale && tier != maxTier) {
    throw ArgumentError.value(
        tier, 'tier', 'only tier $maxTier has a finale (50×50, level 15)');
  }
  return rampTable.firstWhere((s) => s.tier == tier && s.finale == finale);
}
