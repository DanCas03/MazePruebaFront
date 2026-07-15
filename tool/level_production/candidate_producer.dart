// tool/level_production/candidate_producer.dart
//
// Producción PURA de un candidato de nivel (front#65): generar → validar →
// serializar. Sin IO ni argumentos de CLI — todo eso vive en `produce.dart`.
// Mantenerlo puro lo hace testeable directamente y reutilizable dentro de un
// isolate (el CLI corre cada semilla en un isolate con timeout para poder
// atrapar semillas que exceden el presupuesto sin abortar el lote).

import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

import 'ramp.dart';
import 'validation.dart';

/// Lo que hace falta para producir UN candidato: un escalón de la rampa fijado
/// a una semilla concreta. La identidad trazable (`cand-tN-sNNN`) se deriva de
/// tier + semilla, bastantes para reproducir el candidato.
class CandidateSpec {
  final RampStep step;
  final int seed;

  const CandidateSpec({required this.step, required this.seed});

  /// Id trazable del candidato. La semilla se rellena a >= 3 dígitos
  /// (`cand-t3-s042`) para que orden lexicográfico ≈ orden numérico.
  String get levelId => 'cand-t${step.tier}-s${seed.toString().padLeft(3, '0')}';
}

/// Resultado de producir un candidato: el JSON listo para escribir más la
/// telemetría que alimenta el manifiesto (dimensiones, flechas colocadas vs.
/// pedidas, densidad lograda, duración).
class CandidateResult {
  final String levelId;
  final int tier;
  final int seed;
  final int cols;
  final int rows;
  final int requestedArrows;
  final int placedArrows;

  /// Fracción de celdas del tablero efectivamente ocupadas por cuerpos de
  /// flecha (densidad LOGRADA, que puede ser menor a la pedida si la caminata
  /// auto-evitante satura: degradación con gracia).
  final double achievedDensity;

  /// Milisegundos que tomó generar + validar el candidato (para el manifiesto
  /// y para vigilar el presupuesto de < 5 s por semilla).
  final int durationMs;

  /// JSON arrow-path del candidato, listo para escribir en `<levelId>.json`.
  final String json;

  const CandidateResult({
    required this.levelId,
    required this.tier,
    required this.seed,
    required this.cols,
    required this.rows,
    required this.requestedArrows,
    required this.placedArrows,
    required this.achievedDensity,
    required this.durationMs,
    required this.json,
  });
}

/// Genera, valida y serializa un candidato. Lanza [CandidateValidationException]
/// si el tablero no cumple las invariantes (el llamador la atrapa y la registra
/// en el manifiesto de errores). Determinista: misma spec ⇒ mismo JSON dentro de
/// la misma versión del SDK.
CandidateResult produceCandidate(CandidateSpec spec) {
  const encoder = LevelJsonEncoder();
  final generator = GraphBoardGenerator();
  final step = spec.step;

  final sw = Stopwatch()..start();
  final board = generator.generate(
    cols: step.cols,
    rows: step.rows,
    arrowCount: step.arrowCount,
    maxPathLen: step.maxPathLen,
    seed: spec.seed,
  );
  validateCandidate(board); // lanza si el candidato es inválido
  sw.stop();

  final placedCells = board.arrows.fold<int>(0, (n, a) => n + a.cells.length);

  return CandidateResult(
    levelId: spec.levelId,
    tier: step.tier,
    seed: spec.seed,
    cols: step.cols,
    rows: step.rows,
    requestedArrows: step.arrowCount,
    placedArrows: board.arrows.length,
    achievedDensity: placedCells / (step.cols * step.rows),
    durationMs: sw.elapsedMilliseconds,
    // `order` es un placeholder de curación: se emite el tier como banda gruesa
    // (la curación humana asigna el orden final 1–15). El id `cand-tN-sNNN`
    // también es placeholder hasta que la curación fije el identificador real.
    json: encoder.encode(
      levelId: spec.levelId,
      board: board,
      timeLimitSec: step.timeLimitSec,
      order: step.tier,
    ),
  );
}
