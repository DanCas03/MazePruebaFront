import 'package:equatable/equatable.dart';

// Choques acumulados (tocar una flecha bloqueada). Regla de dominio
// (ADR 0001, decisión 6): al llegar a [max] la partida se pierde.
class StrikeCount extends Equatable {
  static const int max = 5;

  final int value;
  const StrikeCount(this.value);

  StrikeCount increment() => StrikeCount(value + 1);

  bool get isFatal => value >= max;

  @override
  List<Object?> get props => [value];
}
