import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/leaderboard/entities/leaderboard_entry.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';

/// Carga el ranking de un nivel (front#17). A diferencia del envío del score
/// (fire-and-forget, front#16), **propaga** el error para que la UI muestre
/// estado de error; solo loggea (AOP vía ILoggerService) el intento y el fallo.
class GetLeaderboardUseCase {
  final ILeaderboardRepository _repository;
  final ILoggerService _logger;
  GetLeaderboardUseCase(this._repository, this._logger);

  Future<List<LeaderboardEntry>> execute(LevelId levelId, {int? limit}) async {
    try {
      final entries = await _repository.getLeaderboard(levelId, limit: limit);
      _logger.log(
        'Leaderboard cargado (${entries.length}) nivel ${levelId.value}',
        'GetLeaderboardUseCase',
      );
      return entries;
    } catch (e) {
      _logger.error('Fallo al cargar el leaderboard', 'GetLeaderboardUseCase', e);
      rethrow;
    }
  }
}
