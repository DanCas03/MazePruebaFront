import 'package:flutter_arrow_maze/application/state/level_selection_controller.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_catalog.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/services/tier_gating.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_descriptor.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/tier.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catálogo falso que sirve una lista fija.
class FakeLevelCatalog implements ILevelCatalog {
  final List<LevelDescriptor> items;
  const FakeLevelCatalog([this.items = const []]);
  @override
  Future<List<LevelDescriptor>> getCatalog() async => items;
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

LevelDescriptor levelDescriptor(String id, Tier tier) =>
    LevelDescriptor(levelId: LevelId(id), tier: tier);

/// Override del provider de selección compuesto con fakes (catálogo/progreso) y
/// el `TierGating` real. Reutilizable por cualquier test que monte la pantalla.
Override levelSelectionOverride({
  List<LevelDescriptor> catalog = const [],
  List<LevelProgress> progress = const [],
}) =>
    levelSelectionControllerProvider.overrideWith(
      () => LevelSelectionController(
        FakeLevelCatalog(catalog),
        FakeLevelProgressRepository(progress),
        const TierGating(),
      ),
    );
