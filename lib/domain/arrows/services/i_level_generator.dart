import '../entities/arrow_board.dart';

abstract interface class ILevelGenerator {
  /// Genera un tablero solucionable (construcción DAG). [maxPathLen] acota la
  /// longitud de los caminos doblados. [seed] hace la generación determinista.
  /// [maxPathLen] debe ser >= 2 (longitud minima de un camino).
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  });
}
