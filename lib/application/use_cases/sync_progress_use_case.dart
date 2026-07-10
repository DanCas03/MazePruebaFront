import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/repositories/i_remote_progress_repository.dart';
import '../../domain/board/services/progress_reconciler.dart';

/// Caso de uso: sincroniza el progreso local con el server al autenticarse.
/// Pull remoto → reconcilia con lo local (best score gana) → push del merge →
/// persiste local. Depende solo de puertos (DIP). El error de red se maneja
/// aquí (AOP logging) sin propagar: la sesión y el flujo de UI no se rompen.
class SyncProgressUseCase {
  final IRemoteProgressRepository _remote;
  final ILevelProgressRepository _local;
  final ProgressReconciler _reconciler;
  final ILoggerService _logger;

  static const _ctx = 'SyncProgressUseCase';

  SyncProgressUseCase(
    this._remote,
    this._local,
    this._reconciler,
    this._logger,
  );

  Future<void> execute() async {
    try {
      final remote = await _remote.pull();
      final local = await _local.getAll();
      final merged = _reconciler.reconcile(local, remote);
      await _remote.push(merged);
      // Persistimos el `merged` del cliente y no la respuesta de push(): como
      // `merged ⊇ remote` (lo recién traído por pull) y el merge del server es
      // idempotente para un mismo usuario, `merge(remote, merged) == merged`.
      // Ambos coinciden, así que evitamos un segundo mapeo del payload.
      await _local.upsertAll(merged);
      _logger.log('Progress synced: ${merged.length} level(s)', _ctx);
    } catch (e) {
      _logger.error('Progress sync failed', _ctx, e);
    }
  }
}
