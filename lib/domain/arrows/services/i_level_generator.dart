import '../entities/arrow_board.dart';

abstract interface class ILevelGenerator {
  /// Genera un tablero solucionable (construcción DAG). [seed] hace la
  /// generación determinista (mismo seed ⇒ mismo tablero); null = aleatorio.
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    int? seed,
  });
}
