import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:flutter_arrow_maze/domain/board/entities/level_progress_entry.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/infrastructure/models/level_progress_hive_model.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories_impl/hive_progress_adapter.dart';

void main() {
  late Directory tempDir;
  late Box<LevelProgressHiveModel> box;
  late HiveProgressAdapter adapter;

  setUp(() async {
    // Arrange (común): box real de Hive sobre un directorio temporal. Verifica
    // también la serialización del TypeAdapter, no solo la lógica del adapter.
    tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LevelProgressHiveModelAdapter());
    }
    box = await Hive.openBox<LevelProgressHiveModel>('progress_test');
    adapter = HiveProgressAdapter(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('saveProgress y loadProgress hacen round-trip preservando los VOs',
      () async {
    // Arrange
    const entry = LevelProgressEntry(
      levelId: LevelId(1),
      isCompleted: true,
      bestMoveCount: MoveCount(7),
    );

    // Act
    await adapter.saveProgress(entry);
    final loaded = await adapter.loadProgress(const LevelId(1));

    // Assert
    expect(loaded, isNotNull);
    expect(loaded!.levelId, equals(const LevelId(1)));
    expect(loaded.isCompleted, isTrue);
    expect(loaded.bestMoveCount, equals(const MoveCount(7)));
  });

  test('loadProgress devuelve null para un nivel no guardado', () async {
    // Act
    final loaded = await adapter.loadProgress(const LevelId(99));

    // Assert
    expect(loaded, isNull);
  });
}
