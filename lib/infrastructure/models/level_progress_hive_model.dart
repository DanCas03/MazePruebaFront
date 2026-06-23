import 'package:hive_ce/hive.dart';

part 'level_progress_hive_model.g.dart';

/// Modelo de persistencia Hive para el progreso de un nivel.
///
/// Vive en la capa de infraestructura: traduce el estado del dominio
/// (LevelId / MoveCount / completado) a un registro almacenable por Hive.
/// El dominio nunca conoce este tipo.
@HiveType(typeId: 0)
class LevelProgressHiveModel extends HiveObject {
  @HiveField(0)
  late String levelId;

  @HiveField(1)
  late int moveCount;

  @HiveField(2)
  late bool completed;

  LevelProgressHiveModel({
    required this.levelId,
    required this.moveCount,
    required this.completed,
  });
}
