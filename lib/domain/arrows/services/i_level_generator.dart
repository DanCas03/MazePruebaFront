import '../entities/arrow_board.dart';

abstract interface class ILevelGenerator {
  /// Genera un tablero solucionable mediante construcción DAG.
  ArrowBoard generate({required int cols, required int rows, required int arrowCount});
}
