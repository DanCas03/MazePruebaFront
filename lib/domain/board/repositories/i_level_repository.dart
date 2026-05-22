// lib/domain/board/repositories/i_level_repository.dart

import '../entities/board.dart';
import '../../player/entities/player.dart';

/// Clase auxiliar para devolver ambos elementos
class LevelData {
  final Board board;
  final Player player;

  LevelData({required this.board, required this.player});
}

/// Contrato que la infraestructura deberá cumplir
abstract class ILevelRepository {
  Future<LevelData> loadLevel(int levelId);
}