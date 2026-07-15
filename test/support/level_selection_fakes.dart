import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_arrow_maze/application/providers/level_catalog_provider.dart';
import 'package:flutter_arrow_maze/application/state/level_selection_controller.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repo que nunca se invoca: [StubLevelCatalog] sobreescribe `build()` y no
/// toca el puerto, pero `LevelCatalogNotifier` exige un [ILevelRepository] en
/// su ctor.
class UnusedLevelRepository implements ILevelRepository {
  const UnusedLevelRepository();
  @override
  Future<Either<LevelFailure, List<CatalogEntry>>> listCatalog() =>
      throw UnimplementedError();

  @override
  Future<Either<LevelFailure, Level>> getLevel(LevelId id) =>
      throw UnimplementedError();
}

/// Mapea ids a entradas de campaña (el caso común en los tests del selector; las
/// entradas temáticas se pasan explícitas). Público para que los tests con
/// `builder:` puedan devolver el tipo nuevo del Catálogo.
List<CatalogEntry> campaignEntries(List<LevelId> ids) =>
    [for (final id in ids) CatalogEntry(id: id, section: LevelSection.campaign)];

/// Logger no-op: [StubLevelCatalog] no dispara el prefetch, así que nunca
/// loggea.
class NoopLogger implements ILoggerService {
  const NoopLogger();
  @override
  void log(String message, String context) {}

  @override
  void error(String message, String context, [Object? error]) {}

  @override
  void warn(String message, String context) {}
}

/// Doble de test del Notifier del Catálogo: resuelve `build()` con lo que
/// devuelva (o lance) [_builder], sin red ni prefetch. Aísla a los consumidores
/// del Notifier real (ya cubierto aparte) y fija el "orden de juego" del que se
/// derivan Tiers, posiciones y "siguiente nivel".
class StubLevelCatalog extends LevelCatalogNotifier {
  final FutureOr<List<CatalogEntry>> Function() _builder;

  StubLevelCatalog(List<CatalogEntry> entries) : this.withBuilder(() => entries);

  /// Para forzar loading (future que no resuelve) o error (builder que lanza).
  StubLevelCatalog.withBuilder(this._builder)
      : super(const UnusedLevelRepository(), const NoopLogger());

  @override
  Future<List<CatalogEntry>> build() async => _builder();
}

/// Repo de progreso falso: solo `getAll` importa para el selector; el resto de
/// operaciones no se ejercitan aquí y fallan ruidosamente si se invocan.
class FakeLevelProgressRepository implements ILevelProgressRepository {
  final List<LevelProgress> all;
  const FakeLevelProgressRepository([this.all = const []]);
  @override
  Future<List<LevelProgress>> getAll() async => all;
  @override
  Future<MoveCount?> getProgress(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) =>
      throw UnimplementedError();
  @override
  Future<void> markCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<bool> isCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> upsertAll(List<LevelProgress> progress) =>
      throw UnimplementedError();
}

/// Override del Catálogo remoto stubeado. Se puede fijar por [ids] (todos como
/// campaña, el caso común), por [entries] explícitas (para incluir temáticos) o
/// con un [builder] a medida (para forzar loading/error).
Override stubCatalogOverride({
  List<LevelId> ids = const [],
  List<CatalogEntry>? entries,
  FutureOr<List<CatalogEntry>> Function()? builder,
}) =>
    levelCatalogProvider.overrideWith(
      () => builder != null
          ? StubLevelCatalog.withBuilder(builder)
          : StubLevelCatalog(entries ?? campaignEntries(ids)),
    );

/// Override del controller del selector compuesto con el progreso fake (o un
/// [progressRepository] a medida) y el `TierGating` real.
Override levelSelectionControllerOverride({
  List<LevelProgress> progress = const [],
  ILevelProgressRepository? progressRepository,
}) =>
    levelSelectionControllerProvider.overrideWith(
      () => LevelSelectionController(
        progressRepository ?? FakeLevelProgressRepository(progress),
        const TierGating(),
      ),
    );

/// Overrides del selector compuestos con fakes y el `TierGating` real: el
/// Catálogo remoto se stubea con [catalogIds] (los Tiers se derivan de la
/// POSICIÓN, 3 niveles por Tier) y el progreso con [progress] (o un
/// [progressRepository] a medida). Reutilizable por cualquier test que monte la
/// pantalla; el controller exige AMBOS providers (front#8: lee el Catálogo de
/// `levelCatalogProvider` vía `watch`).
List<Override> levelSelectionOverrides({
  List<LevelId> catalogIds = const [],
  List<CatalogEntry>? catalogEntries,
  List<LevelProgress> progress = const [],
  ILevelProgressRepository? progressRepository,
}) =>
    [
      stubCatalogOverride(ids: catalogIds, entries: catalogEntries),
      levelSelectionControllerOverride(
        progress: progress,
        progressRepository: progressRepository,
      ),
    ];
