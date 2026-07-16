import '../../core/aspects/i_logger_service.dart';
import '../../domain/leaderboard/entities/score_entry.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';
import '../../domain/leaderboard/value_objects/canonical_result.dart';

/// Envía el score al ganar (front#16). Resiliente: un fallo de red (o una
/// respuesta inválida) se loggea y se traga (AOP vía ILoggerService), para que
/// la victoria nunca se rompa. El disparo es fire-and-forget desde el
/// Observer; este use case no relanza — devuelve `null` en fallo.
class SubmitScoreUseCase {
  final ILeaderboardRepository _repository;
  final ILoggerService _logger;
  SubmitScoreUseCase(this._repository, this._logger);

  /// Devuelve el resultado CANÓNICO (ADR 0006) en éxito, o `null` si el envío
  /// falla.
  Future<CanonicalResult?> execute(ScoreEntry entry) async {
    try {
      final canonical = await _repository.submitScore(entry);
      _logger.log(
          'Score enviado para nivel ${entry.levelId.value}', 'SubmitScoreUseCase');
      return canonical;
    } catch (e) {
      _logger.error('Fallo al enviar el score', 'SubmitScoreUseCase', e);
      return null;
    }
  }
}
