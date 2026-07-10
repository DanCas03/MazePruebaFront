import '../value_objects/level_progress.dart';

/// Puerto (DIP) del sync remoto de progreso contra `/progress` (back#8). La
/// infraestructura decide el transporte (Dio); el dominio solo conoce este
/// contrato pequeño y cohesivo (ISP).
abstract interface class IRemoteProgressRepository {
  /// Trae el progreso del usuario autenticado (GET /progress).
  Future<List<LevelProgress>> pull();

  /// Envía el progreso reconciliado (POST /progress) y devuelve el merge del
  /// server (idempotente).
  Future<List<LevelProgress>> push(List<LevelProgress> progress);
}
