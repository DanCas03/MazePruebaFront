import 'package:equatable/equatable.dart';

/// Puntaje numérico y determinista de una partida ganada.
///
/// Regla de dominio (ADR 0001, decisión 7):
/// `score = f(tiempo, movimientos sobre óptimo, choques)`. Partimos de una base
/// fija y descontamos penalizaciones por cada segundo, cada movimiento por
/// encima del óptimo y cada choque. El resultado se acota a `[0, base]` para que
/// nunca sea negativo. Alimenta el `Leaderboard` por score/nivel.
class Score extends Equatable {
  /// Puntaje de una partida perfecta (sin penalización).
  static const int base = 10000;

  /// Penalización por segundo transcurrido.
  static const int timePenaltyPerSecond = 5;

  /// Penalización por cada movimiento por encima del óptimo.
  static const int extraMovePenalty = 100;

  /// Penalización por cada choque.
  static const int collisionPenalty = 250;

  final int value;

  const Score(this.value)
      : assert(value >= 0, 'Score must not be negative');

  /// Calcula el puntaje de una partida ganada a partir de sus métricas.
  ///
  /// [time] es la duración de la partida, [moves] los movimientos realizados,
  /// [optimalMoves] el óptimo del nivel (número de flechas) y [collisions] la
  /// cuenta de choques. Los movimientos por debajo del óptimo no penalizan: el
  /// exceso se acota a `0`.
  factory Score.fromRun({
    required Duration time,
    required int moves,
    required int optimalMoves,
    required int collisions,
  }) {
    final seconds = time.inSeconds < 0 ? 0 : time.inSeconds;
    final extraMoves = (moves - optimalMoves).clamp(0, moves);
    final safeCollisions = collisions < 0 ? 0 : collisions;

    final raw = base -
        seconds * timePenaltyPerSecond -
        extraMoves * extraMovePenalty -
        safeCollisions * collisionPenalty;

    return Score(raw.clamp(0, base));
  }

  @override
  List<Object?> get props => [value];
}
