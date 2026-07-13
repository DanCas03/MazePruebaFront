import 'package:dartz/dartz.dart';

import '../entities/level.dart';
import '../failures/level_failure.dart';
import '../value_objects/level_id.dart';

/// Puerto (DIP) de acceso a los niveles oficiales de la campaña. La app depende
/// de esta abstracción; la impl remota (con caché) vive en infrastructure. El
/// prefetch NO es método del puerto: lo orquesta la capa de aplicación
/// reutilizando [getLevel] (el repo cachea como efecto natural).
///
/// Nota (front#9): la fuente de nivel de la campaña es **DIP** —este puerto con
/// un único Adapter remoto (`RemoteLevelRepository`)—, no el "Strategy
/// remoto/procedural" que imaginaba E1.5. La generación procedimental es la
/// feature GeneratedBoard (#36/#37), fuera de este puerto. Ver README
/// §"Campaña remota".
abstract interface class ILevelRepository {
  /// Ids del Catálogo en orden de juego (GET /levels).
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds();

  /// Nivel completo por id (GET /levels/:id), network-first con fallback a caché.
  Future<Either<LevelFailure, Level>> getLevel(LevelId id);
}
