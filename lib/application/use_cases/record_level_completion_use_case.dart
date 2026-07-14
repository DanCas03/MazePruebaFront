import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/repositories/i_level_progress_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/board/value_objects/level_progress.dart';

/// front#58: persiste el progreso de un nivel al GANARLO. Cierra el eslabón que
/// faltaba en el bucle de progresión: sin este productor, las estrellas del
/// selector de nivel y el gating de tiers (front#20) nunca se alimentaban del
/// juego real — el único escritor local era el sync al login (front#18).
///
/// Merge "best-of": conserva el MEJOR score/estrellas entre repeticiones, para
/// que rejugar peor un nivel no degrade el récord (coherente con la
/// reconciliación "mejor gana" de `ProgressReconciler`, front#18).
class RecordLevelCompletionUseCase {
  final ILevelProgressRepository _progress;
  final ILoggerService _log;
  static const _ctx = 'RecordLevelCompletionUseCase';

  RecordLevelCompletionUseCase(this._progress, this._log);

  Future<void> execute(
    LevelId levelId, {
    required int score,
    required int stars,
  }) async {
    try {
      final existing = await _findExisting(levelId);
      await _progress.upsertAll([
        LevelProgress(
          levelId: levelId,
          completed: true,
          bestScore: _bestOf(existing?.bestScore, score),
          bestStars: _bestOf(existing?.bestStars, stars),
        ),
      ]);
      _log.log(
        'Recorded completion for ${levelId.value} '
        '(stars=${_bestOf(existing?.bestStars, stars)}, '
        'score=${_bestOf(existing?.bestScore, score)})',
        _ctx,
      );
    } catch (e) {
      // Se invoca fire-and-forget desde el observer: un fallo de persistencia no
      // debe romper la transición a la pantalla de victoria. Se registra y se
      // traga (mismo criterio que el observer de envío de score, front#16).
      _log.error('Failed to record completion for ${levelId.value}', _ctx, e);
    }
  }

  Future<LevelProgress?> _findExisting(LevelId levelId) async {
    final all = await _progress.getAll();
    for (final p in all) {
      if (p.levelId == levelId) return p;
    }
    return null;
  }

  /// El mayor entre el récord previo (si existe) y el valor del run actual.
  int _bestOf(int? previous, int current) =>
      (previous != null && previous > current) ? previous : current;
}
