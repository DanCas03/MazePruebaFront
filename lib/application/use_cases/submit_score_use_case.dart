import '../../core/aspects/i_logger_service.dart';
import '../../domain/leaderboard/entities/score_entry.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';

/// Envía el score al ganar (front#16). Resiliente: un fallo de red se loggea y
/// se traga (AOP vía ILoggerService), para que la victoria nunca se rompa. El
/// disparo es fire-and-forget desde el Observer; este use case no relanza.
class SubmitScoreUseCase {
  final ILeaderboardRepository _repository;
  final ILoggerService _logger;
  SubmitScoreUseCase(this._repository, this._logger);

  Future<void> execute(ScoreEntry entry) async {
    try {
      await _repository.submitScore(entry);
      _logger.log(
          'Score enviado para nivel ${entry.levelId.value}', 'SubmitScoreUseCase');
    } catch (e) {
      _logger.error('Fallo al enviar el score', 'SubmitScoreUseCase', e);
    }
  }
}
