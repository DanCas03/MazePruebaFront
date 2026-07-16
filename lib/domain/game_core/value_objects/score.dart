import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Puntaje PREVIEW de una partida ganada (ADR 0006).
///
/// El canónico lo deriva el backend de las métricas del run; esta fórmula se
/// duplica aquí a sabiendas, solo para feedback inmediato y modo offline.
/// Puede divergir tras un tuning de constantes en el back sin romper nada:
/// la pantalla de victoria se reconcilia con la respuesta del POST.
class Score extends Equatable {
  /// Puntaje de una partida perfecta (sin penalización).
  static const int base = 10000;

  /// Exponente de la precisión de movimientos: (óptimo/movimientos)^exp.
  static const int moveExponent = 2;

  /// Factor multiplicativo por cada choque: 0.8^choques.
  static const double collisionFactor = 0.8;

  /// Par de tiempo como fracción del límite del nivel: par = timeLimitSec × ratio.
  static const double parRatio = 0.5;

  /// Piso del puntaje de una partida ganada: nunca por debajo de este valor.
  static const int minWinScore = 100;

  /// Par de reserva cuando el nivel no trae límite (caché legada): 3s/flecha.
  static const int fallbackParSecondsPerArrow = 3;

  final int value;

  /// Invariante de dominio validada en tiempo de ejecución (no con `assert`,
  /// que se elimina en builds release): un puntaje nunca es negativo. Coherente
  /// con `AuthToken` en este repo y con el VO `Score` del back (contrato de
  /// `ScoreEntry`/`SubmitScore`, ADR 0001 decisión 7).
  Score(this.value) {
    if (value < 0) {
      throw ArgumentError('Score must not be negative');
    }
  }

  /// Calcula el puntaje PREVIEW de una partida ganada a partir de sus métricas.
  ///
  /// [time] es la duración de la partida, [moves] los movimientos realizados,
  /// [optimalMoves] el óptimo del nivel (número de flechas), [collisions] la
  /// cuenta de choques y [timeLimitSec] el límite de tiempo del nivel (o
  /// `null` si el nivel no trae límite — caché legada), del que se deriva el
  /// par de tiempo. La fórmula es multiplicativa:
  /// `round(base × (óptimo/max(moves,óptimo))² × collisionFactor^choques ×
  /// 2^(−segundos/par))`, acotada al piso [minWinScore].
  factory Score.fromRun({
    required Duration time,
    required int moves,
    required int optimalMoves,
    required int collisions,
    required int? timeLimitSec,
  }) {
    final optimal = optimalMoves < 1 ? 1 : optimalMoves;
    final safeMoves = moves < optimal ? optimal : moves;
    final safeCollisions = collisions < 0 ? 0 : collisions;
    final seconds = time.inSeconds < 0 ? 0 : time.inSeconds;

    final par = timeLimitSec != null
        ? timeLimitSec * parRatio
        : (optimal * fallbackParSecondsPerArrow).toDouble();

    final precision = math.pow(optimal / safeMoves, moveExponent) *
        math.pow(collisionFactor, safeCollisions);
    final timeFactor = math.pow(2, -seconds / par);

    final raw = (base * precision * timeFactor).round();
    return Score(raw < minWinScore ? minWinScore : raw);
  }

  @override
  List<Object?> get props => [value];
}
