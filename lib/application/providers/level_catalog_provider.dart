import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/repositories/i_level_repository.dart';
import '../../domain/board/value_objects/level_id.dart';

/// Se compone en main (DIP); la fábrica por defecto falla para no acoplar a
/// impls concretas antes de que existan.
final levelCatalogProvider =
    AsyncNotifierProvider<LevelCatalogNotifier, List<LevelId>>(
  () => throw UnimplementedError(
    'levelCatalogProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva del Catálogo (orden de juego). Al cargar los ids dispara un
/// prefetch oportunista en segundo plano de toda la campaña, reutilizando
/// [ILevelRepository.getLevel] (que cachea como efecto natural): con una visita
/// online, la campaña queda jugable offline. Los fallos individuales del
/// prefetch se loggean y se tragan (nunca afectan a la UI). [refresh] re-ejecuta
/// build() para el retry de la UI.
class LevelCatalogNotifier extends AsyncNotifier<List<LevelId>> {
  final ILevelRepository _repository;
  final ILoggerService _logger;

  LevelCatalogNotifier(this._repository, this._logger);

  @override
  Future<List<LevelId>> build() async {
    final result = await _repository.listLevelIds();
    return result.fold(
      (failure) => throw failure, // AsyncNotifier lo captura → AsyncValue.error
      (ids) {
        unawaited(_prefetch(ids));
        return ids;
      },
    );
  }

  /// Retry de la UI: re-ejecuta build() (loading → data/error).
  void refresh() => ref.invalidateSelf();

  /// Prefetch SECUENCIAL (no ametrallar al back) y oportunista: cada fallo se
  /// loggea y se traga; el prefetch nunca cambia el estado del provider.
  Future<void> _prefetch(List<LevelId> ids) async {
    for (final id in ids) {
      final result = await _repository.getLevel(id);
      result.fold(
        (failure) => _logger.warn(
            'prefetch failed for ${id.value}: ${failure.message}',
            'LevelCatalog'),
        (_) {}, // cacheado como efecto natural; nada más que hacer
      );
    }
  }
}
