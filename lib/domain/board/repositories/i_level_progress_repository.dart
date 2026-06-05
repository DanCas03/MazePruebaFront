// lib/domain/board/repositories/i_level_progress_repository.dart

import '../../game_core/value_objects/level_id.dart';
import '../entities/level_progress_entry.dart';

/// Puerto (interfaz) para persistir el progreso del jugador.
///
/// DIP: el dominio y los casos de uso dependen de esta abstracción; nunca de
/// Hive/Sqflite. El adaptador concreto (Capa 4) la implementa. Esto permite
/// intercambiar el motor de persistencia sin tocar la lógica de negocio.
abstract class ILevelProgressRepository {
  /// Devuelve el progreso de un nivel, o `null` si nunca se ha jugado.
  Future<LevelProgressEntry?> loadProgress(LevelId levelId);

  /// Crea o actualiza el progreso de un nivel.
  Future<void> saveProgress(LevelProgressEntry entry);

  /// Devuelve el progreso de todos los niveles registrados.
  Future<List<LevelProgressEntry>> loadAllProgress();
}
