// tool/level_production/validation.dart
//
// Validación integrada del productor de candidatos (front#65): antes de
// escribir un candidato al disco, se comprueba que el tablero cumpla las DOS
// invariantes del wire contract, de forma independiente al generador (defensa
// en profundidad — el generador ya las garantiza por construcción, pero un
// candidato inválido nunca debe congelarse como artefacto de curación).
//
//   1. Sin solape: cada celda pertenece a lo sumo a una flecha.
//   2. Vaciado en orden inverso: quitando las flechas en el orden inverso al de
//      colocación, cada una puede salir en su turno hasta vaciar el tablero
//      (solubilidad por construcción del DAG — el LevelSolver del back es la
//      autoridad última, pero esta comprobación local ataja candidatos rotos).

import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Fallo de validación de un candidato: el tablero generado no cumple una
/// invariante del wire contract y NO debe escribirse. El productor la propaga
/// para que el CLI la registre en el manifiesto de errores y continúe.
class CandidateValidationException implements Exception {
  final String message;
  const CandidateValidationException(this.message);
  @override
  String toString() => 'CandidateValidationException: $message';
}

/// true si ninguna celda está ocupada por más de una flecha.
bool hasNoOverlap(ArrowBoard board) {
  final seen = <Position>{};
  for (final arrow in board.arrows) {
    for (final cell in arrow.cells) {
      if (!seen.add(cell)) return false;
    }
  }
  return true;
}

/// true si el tablero se vacía quitando las flechas en el orden INVERSO al de
/// colocación (la última colocada sale primero): invariante DAG de solubilidad.
bool emptiesInReverseOrder(ArrowBoard board) {
  var live = board;
  // `arrows` está en orden de colocación; se recorre del final al inicio.
  for (final arrow in board.arrows.reversed) {
    if (!live.canExit(arrow.id)) return false;
    live = live.removeArrow(arrow.id);
  }
  return live.isCleared;
}

/// Comprueba ambas invariantes; lanza [CandidateValidationException] con un
/// mensaje concreto en el primer fallo. No devuelve nada si el tablero es
/// válido (fail-fast, pensado para envolver en try/catch).
void validateCandidate(ArrowBoard board) {
  if (board.arrows.isEmpty) {
    throw const CandidateValidationException('board has no arrows');
  }
  if (!hasNoOverlap(board)) {
    throw const CandidateValidationException('two arrows share a cell (overlap)');
  }
  if (!emptiesInReverseOrder(board)) {
    throw const CandidateValidationException(
        'board does not empty in reverse placement order (unsolvable)');
  }
}
