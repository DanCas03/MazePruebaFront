import '../value_objects/level_progress.dart';

/// Servicio de dominio puro: fusiona el progreso local y el remoto sin degradar
/// ninguno (best score gana, un nivel completado en cualquier lado queda
/// completado). Reproduce la regla del back (SyncProgressUseCase.merge) para
/// dejar el estado local correcto sin depender del orden de respuesta del server.
class ProgressReconciler {
  List<LevelProgress> reconcile(
    List<LevelProgress> local,
    List<LevelProgress> remote,
  ) {
    final byId = <String, LevelProgress>{};
    for (final p in local) {
      byId[p.levelId.value] = p;
    }
    for (final p in remote) {
      final existing = byId[p.levelId.value];
      byId[p.levelId.value] = existing == null ? p : _merge(existing, p);
    }
    return byId.values.toList();
  }

  LevelProgress _merge(LevelProgress a, LevelProgress b) => LevelProgress(
        levelId: a.levelId,
        completed: a.completed || b.completed,
        bestScore: _maxNullable(a.bestScore, b.bestScore),
        bestStars: _maxNullable(a.bestStars, b.bestStars),
      );

  int? _maxNullable(int? a, int? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a >= b ? a : b;
  }
}
