import 'package:dartz/dartz.dart';

import '../../arrows/value_objects/arrow_id.dart';
import '../failures/solution_failure.dart';
import '../value_objects/level_id.dart';

/// Puerto (DIP) de la Solución canónica de un nivel: el orden de [ArrowId] que
/// vacía el tablero (back#19, `GET /levels/:id/solution`). La app depende de
/// esta abstracción; la impl remota vive en infrastructure. La lengua del cable
/// son ids planos (CONTEXT-MAP): ningún modelo de dominio cruza el HTTP y el
/// cliente reproduce el orden **verbatim**, sin derivar nada.
///
/// Sin caché: una pista es on-demand y no bloquea la partida, así que offline (o
/// timeout) resuelve [SolutionUnavailable] en vez de servir una copia vieja.
abstract interface class ISolutionRepository {
  Future<Either<SolutionFailure, List<ArrowId>>> getSolution(LevelId id);
}
