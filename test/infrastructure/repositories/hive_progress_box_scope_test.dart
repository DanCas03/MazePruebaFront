import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:flutter_arrow_maze/infrastructure/data_sources/local/hive_level_progress_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/models/level_progress_hive_model.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/hive_progress_box_scope.dart';

/// Regresión del bug "el progreso se comparte entre cuentas".
///
/// Ejercita el camino real de persistencia (DataSource → [HiveProgressBoxScope]
/// → Hive) contra un Hive de disco temporal. Con el diseño anterior (una sola
/// caja global `level_progress`) la cuenta B veía el progreso de A; aquí se
/// verifica que cada `userId` obtiene su propia caja aislada.
void main() {
  late Directory tempDir;
  late HiveProgressBoxScope scope;
  late HiveLocalDataSource dataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('progress_scope_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(LevelProgressHiveModelAdapter());
    }
    scope = HiveProgressBoxScope();
    dataSource = HiveLocalDataSource(scope);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('cada cuenta abre una caja Hive namespaced por su userId', () async {
    // Arrange / Act
    await scope.activate('user-a');
    // Assert
    expect(scope.box.name, HiveProgressBoxScope.boxNameFor('user-a'));
    expect(scope.box.name, 'level_progress_user-a');
  });

  test('box lanza StateError si no hay alcance activo (fail-fast)', () {
    // Arrange — sin activate previo
    // Act / Assert
    expect(() => scope.box, throwsStateError);
  });

  test(
      'el progreso de una cuenta NO es visible desde otra cuenta (aislamiento)',
      () async {
    // Arrange — la cuenta A completa el nivel 1 con score/estrellas
    await scope.activate('user-a');
    await dataSource.upsertProgress('level-1', true, 900, 3);
    expect(dataSource.getAllProgress(), hasLength(1));
    await scope.deactivate();

    // Act — la cuenta B inicia sesión (caja propia, recién abierta)
    await scope.activate('user-b');

    // Assert — B arranca SIN el progreso de A (antes del fix: lo heredaba)
    expect(dataSource.getAllProgress(), isEmpty);
    expect(dataSource.isCompleted('level-1'), isFalse);
  });

  test('cada cuenta conserva su propio progreso al reactivarse', () async {
    // Arrange — A guarda level-1; B guarda level-2
    await scope.activate('user-a');
    await dataSource.markCompleted('level-1');
    await scope.deactivate();

    await scope.activate('user-b');
    await dataSource.markCompleted('level-2');
    await scope.deactivate();

    // Act / Assert — al volver a A, ve SOLO lo suyo
    await scope.activate('user-a');
    expect(dataSource.isCompleted('level-1'), isTrue);
    expect(dataSource.isCompleted('level-2'), isFalse);
    await scope.deactivate();

    // Y al volver a B, ve SOLO lo suyo
    await scope.activate('user-b');
    expect(dataSource.isCompleted('level-2'), isTrue);
    expect(dataSource.isCompleted('level-1'), isFalse);
  });

  test('activate es idempotente para la misma cuenta', () async {
    // Arrange
    await scope.activate('user-a');
    await dataSource.markCompleted('level-1');
    // Act — reactivar la misma cuenta no pierde ni duplica datos
    await scope.activate('user-a');
    // Assert
    expect(dataSource.isCompleted('level-1'), isTrue);
    expect(dataSource.getAllProgress(), hasLength(1));
  });
}
