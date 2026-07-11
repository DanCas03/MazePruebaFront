import 'package:equatable/equatable.dart';

/// Calificación de estrellas de una partida ganada (1–3).
///
/// Regla de dominio (ADR 0001, decisión 7): las estrellas resumen la calidad
/// de la solución en función de los movimientos por encima del óptimo y de los
/// choques. Completar el nivel garantiza al menos 1★; la excelencia (3★) exige
/// cero choques y resolver casi en la ruta óptima.
class Stars extends Equatable {
  /// Movimientos extra sobre el óptimo tolerados para conservar las 3★ (la `k`
  /// de la fórmula `movimientos ≤ óptimo + k`).
  static const int perfectMoveTolerance = 2;

  /// Cotas para 2★: hasta este número de choques y de movimientos extra.
  static const int twoStarMaxCollisions = 2;
  static const int twoStarMoveTolerance = 6;

  final int value;

  const Stars._(this.value);

  const Stars.one() : value = 1;
  const Stars.two() : value = 2;
  const Stars.three() : value = 3;

  /// Califica una partida ganada a partir de sus métricas.
  ///
  /// [moves] son los movimientos realizados y [optimalMoves] el óptimo del
  /// nivel (número de flechas). [collisions] es la cuenta de choques. Los
  /// movimientos por debajo del óptimo no otorgan crédito extra: el exceso se
  /// acota a `0`.
  factory Stars.rate({
    required int moves,
    required int optimalMoves,
    required int collisions,
  }) {
    final extraMoves = (moves - optimalMoves).clamp(0, moves);
    if (collisions == 0 && extraMoves <= perfectMoveTolerance) {
      return const Stars._(3);
    }
    if (collisions <= twoStarMaxCollisions && extraMoves <= twoStarMoveTolerance) {
      return const Stars._(2);
    }
    return const Stars._(1);
  }

  /// Reconstruye las estrellas desde un valor persistido o recibido por red
  /// (leaderboard, front#17): el back ya calculó la calificación y solo envía el
  /// entero. Valida la cota de dominio `[1, 3]` en runtime (no con `assert`, que
  /// se elimina en release).
  factory Stars.fromValue(int value) {
    if (value < 1 || value > 3) {
      throw ArgumentError('Stars value must be between 1 and 3');
    }
    return Stars._(value);
  }

  @override
  List<Object?> get props => [value];
}
