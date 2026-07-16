import 'package:equatable/equatable.dart';

// Choques cometidos (tocar una flecha bloqueada) contra un presupuesto [max].
// Regla de dominio (ADR 0001, decisión 6): al agotar el presupuesto la partida
// se pierde. El modelo interno CUENTA los choques cometidos (el scoring los usa
// como `collisions`); el contador que ve el jugador es [remaining], que
// DESCIENDE — la vista descendente sobre el mismo dato (front#83).
//
// [max] es por instancia para soportar un presupuesto POR NIVEL (Level.maxErrors);
// omitirlo usa [defaultMax], el presupuesto de los tableros generados (sin Level).
class StrikeCount extends Equatable {
  /// Presupuesto de errores por defecto cuando el nivel no fija uno propio.
  static const int defaultMax = 5;

  final int value;
  final int max;
  const StrikeCount(this.value, {this.max = defaultMax});

  StrikeCount increment() => StrikeCount(value + 1, max: max);

  /// Errores que aún puede cometer el jugador (contador descendente del HUD).
  /// Nunca negativo aunque `value` superara `max` por una carrera defensiva.
  int get remaining => (max - value).clamp(0, max);

  bool get isFatal => value >= max;

  @override
  List<Object?> get props => [value, max];
}
