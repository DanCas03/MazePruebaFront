import '../entities/arrow_board.dart';

abstract interface class ILevelGenerator {
  /// Genera un tablero solucionable (construcción DAG). [maxPathLen] acota la
  /// longitud de los caminos doblados. [seed] hace la generación determinista.
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  });
}
