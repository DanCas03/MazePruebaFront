import '../../domain/leaderboard/entities/global_leaderboard.dart';
import '../../domain/leaderboard/repositories/i_leaderboard_repository.dart';

/// Lee el ranking general de jugadores (ADR 0006). Solo lectura; los totales
/// (mejor score/estrellas por nivel de campaña) los agrega el back — aquí no
/// hay regla de negocio, solo la fachada de application sobre el puerto.
/// Propaga los errores para que el provider los exponga como `AsyncError`.
class GetGlobalLeaderboardUseCase {
  final ILeaderboardRepository _repository;
  GetGlobalLeaderboardUseCase(this._repository);

  Future<GlobalLeaderboard> execute() => _repository.getGlobalLeaderboard();
}
