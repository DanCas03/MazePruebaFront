import 'package:dartz/dartz.dart';

import '../entities/level.dart';
import '../failures/level_failure.dart';
import '../value_objects/level_id.dart';

/// Puerto (DIP) de acceso a los niveles oficiales de la campaña. La app depende
/// de esta abstracción; la impl remota (con caché) vive en infrastructure. El
/// prefetch NO es método del puerto: lo orquesta la capa de aplicación
/// reutilizando [getLevel] (el repo cachea como efecto natural).
abstract interface class ILevelRepository {
  /// Ids del Catálogo en orden de juego (GET /levels).
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds();

  /// Nivel completo por id (GET /levels/:id), network-first con fallback a caché.
  Future<Either<LevelFailure, Level>> getLevel(LevelId id);
}
