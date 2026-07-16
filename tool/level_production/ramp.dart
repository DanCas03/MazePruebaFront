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
// × 3, culminando en un 28×50), material de curación humana.
//
// La campaña conserva su estructura 15 = 5 tiers × 3. El tier 5 tiene DOS
// perfiles: los niveles 13–14 (25×44) y el remate nivel 15 (28×50), que se pide
// con `finale: true`.
//
// back#46 (reshape 9:16): todas las dimensiones se reformaron a la banda de
// aspecto retrato de la app ([AspectBand], target 9:16, [0.53,0.68]) — antes
// eran near-square/portrait suave. `rampStepFor` verifica con un assert que
// todo escalón devuelto cae dentro de la banda, así un futuro cambio de tabla
// que se salga de rango falla rápido en debug/test en vez de colar un tablero
// desproporcionado a producción.

import 'package:flutter_arrow_maze/domain/arrows/value_objects/aspect_band.dart';

/// Un escalón de la rampa: los parámetros de generación de un tier (o del
/// remate). `arrowCount` y `timeLimitSec` se DERIVAN de estos campos con la
/// misma fórmula de densidad que la campaña; el productor no elige números.
class RampStep {
  /// Tier de la campaña (1–5) al que pertenece el candidato. Determina el
  /// prefijo trazable del id: `cand-t<tier>-s<seed>`.
  final int tier;

  /// true ⇒ es el remate de la campaña (nivel 15, 28×50), no los niveles
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
  /// Todos los tiers de la campaña están cronometrados (feedback de
  /// mantenedor, back#46): ya no hay escalones sin límite.
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
/// remate 28×50 del tier 5 (nivel 15). Ordenada por dificultad creciente. Todas
/// las dimensiones caen dentro de [AspectBand] (back#46, reshape 9:16).
const List<RampStep> rampTable = [
  // T1 (niveles 1–3) — 6×10, con límite derivado.
  RampStep(tier: 1, finale: false, cols: 6, rows: 10, fillRatio: 0.30, maxPathLen: 3, timed: true),
  // T2 (niveles 4–6) — 9×16, con límite derivado.
  RampStep(tier: 2, finale: false, cols: 9, rows: 16, fillRatio: 0.38, maxPathLen: 5, timed: true),
  // T3 (niveles 7–9) — 12×22, con límite derivado.
  RampStep(tier: 3, finale: false, cols: 12, rows: 22, fillRatio: 0.45, maxPathLen: 7, timed: true),
  // T4 (niveles 10–12) — 19×34, con límite derivado.
  RampStep(tier: 4, finale: false, cols: 19, rows: 34, fillRatio: 0.62, maxPathLen: 10, timed: true),
  // T5 (niveles 13–14) — 25×44, con límite derivado.
  RampStep(tier: 5, finale: false, cols: 25, rows: 44, fillRatio: 0.75, maxPathLen: 12, timed: true),
  // T5 (nivel 15, remate) — 28×50, con límite derivado, densidad casi total.
  RampStep(tier: 5, finale: true, cols: 28, rows: 50, fillRatio: 0.90, maxPathLen: 12, timed: true),
];

/// Tier mínimo/máximo aceptados por la rampa (útil para validar CLI args).
const int minTier = 1;
const int maxTier = 5;

/// El escalón de la rampa para [tier], o su remate 28×50 si [finale] es true.
/// Lanza [ArgumentError] si el tier está fuera de rango, o si se pide remate
/// para un tier que no sea el 5 (solo la campaña remata en el tier 5).
///
/// back#46: verifica con un assert que el escalón devuelto cae dentro de
/// [AspectBand] — guarda contra una futura edición de `rampTable` que
/// reintroduzca dimensiones fuera de la banda 9:16 de la app.
RampStep rampStepFor(int tier, {bool finale = false}) {
  if (tier < minTier || tier > maxTier) {
    throw ArgumentError.value(tier, 'tier', 'must be between $minTier and $maxTier');
  }
  if (finale && tier != maxTier) {
    throw ArgumentError.value(
        tier, 'tier', 'only tier $maxTier has a finale (28×50, level 15)');
  }
  final step = rampTable.firstWhere((s) => s.tier == tier && s.finale == finale);
  assert(AspectBand.contains(step.cols, step.rows),
      'ramp step ${step.cols}x${step.rows} out of aspect band');
  return step;
}
