# front#18 — Progress Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sincronizar el progreso local (Hive) con el servidor: al autenticarse, pull remoto → reconciliar (best score gana) → push del merge → persistir local, sin romper el flujo ante error de red.

**Architecture:** Clean Mobile Architecture. Un VO `LevelProgress` (Dart puro) modela el progreso reconciliable; un `ProgressReconciler` puro aplica la regla de merge; un puerto remoto `IRemoteProgressRepository` (impl Dio) hace push/pull contra `/progress`; el puerto local `ILevelProgressRepository` gana `getAll`/`upsertAll` sobre un Hive model extendido; un `SyncProgressUseCase` orquesta y se dispara vía `ref.listen(authControllerProvider)` en `AuthGate`.

**Tech Stack:** Flutter, Riverpod, Hive CE, Dio, Equatable, mockito, build_runner.

## Global Constraints

- Package raíz de imports en tests: `package:flutter_arrow_maze/...`.
- `domain/` es Dart puro: solo `equatable` como dependencia externa (patrón ya usado por `LevelId`/`MoveCount`). Sin imports de Flutter/Dio/Hive en `domain/`.
- AOP: nada de `print`/`Logger` directo; usar `ILoggerService` inyectado (`log(msg, ctx)`, `error(msg, ctx, [err])`, `warn(msg, ctx)`).
- Tests AAA con nombres `should_..._when_...`. Mockear dependencias externas.
- Regeneración de código (Hive adapter + mocks de mockito): `export PATH="/opt/homebrew/bin:$PATH" && dart run build_runner build --delete-conflicting-outputs` (Flutter/Dart no están en el PATH del shell por defecto).
- Correr tests: `export PATH="/opt/homebrew/bin:$PATH" && flutter test <ruta>`. Analyze: `export PATH="/opt/homebrew/bin:$PATH" && flutter analyze`.
- No modificar los métodos existentes de `ILevelProgressRepository` (`getProgress/saveProgress/markCompleted/isCompleted`) — solo añadir (OCP/LSP).
- Conventional Commits, **un fragmento por commit**, cada uno con su entrada en `AI_HISTORY.MD` (raíz de `MazePruebaFront/`). Cada commit termina con `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- `flutter analyze` limpio antes de cada commit de código.

---

### Task 1: `LevelProgress` value object

**Files:**
- Create: `lib/domain/board/value_objects/level_progress.dart`
- Test: `test/domain/board/value_objects/level_progress_test.dart`

**Interfaces:**
- Consumes: `LevelId` (`lib/domain/board/value_objects/level_id.dart`).
- Produces: `class LevelProgress extends Equatable` con constructor
  `LevelProgress({required LevelId levelId, required bool completed, int? bestScore, int? bestStars})`
  y campos `levelId`, `completed`, `bestScore`, `bestStars`. Lanza `ArgumentError` si `bestScore! < 0` o `bestStars` fuera de `1..3`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/board/value_objects/level_progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';

void main() {
  group('LevelProgress', () {
    test('should_hold_fields_when_constructed_with_valid_values', () {
      // Arrange / Act
      final p = LevelProgress(
          levelId: LevelId('1'), completed: true, bestScore: 1200, bestStars: 3);
      // Assert
      expect(p.levelId, LevelId('1'));
      expect(p.completed, isTrue);
      expect(p.bestScore, 1200);
      expect(p.bestStars, 3);
    });

    test('should_allow_null_score_and_stars_when_level_completed_without_score', () {
      // Arrange / Act
      final p = LevelProgress(levelId: LevelId('2'), completed: true);
      // Assert
      expect(p.bestScore, isNull);
      expect(p.bestStars, isNull);
    });

    test('should_be_value_equal_when_all_fields_match', () {
      // Arrange / Act
      final a = LevelProgress(levelId: LevelId('1'), completed: false, bestScore: 0);
      final b = LevelProgress(levelId: LevelId('1'), completed: false, bestScore: 0);
      // Assert
      expect(a, equals(b));
    });

    test('should_throw_when_bestScore_is_negative', () {
      // Arrange / Act / Assert
      expect(
        () => LevelProgress(levelId: LevelId('1'), completed: true, bestScore: -1),
        throwsArgumentError,
      );
    });

    test('should_throw_when_bestStars_out_of_range', () {
      // Arrange / Act / Assert
      expect(
        () => LevelProgress(levelId: LevelId('1'), completed: true, bestStars: 4),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/domain/board/value_objects/level_progress_test.dart`
Expected: FAIL — `level_progress.dart` no existe (Target of URI doesn't exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/board/value_objects/level_progress.dart
import 'package:equatable/equatable.dart';

import 'level_id.dart';

/// VO inmutable: el progreso reconciliable de un nivel (completado + mejor
/// score/estrellas). Espejo de los campos opcionales de `/progress` (back#8).
///
/// Usa `int?` en vez del `Score`/`Stars` VO de front#12 (aún no mergeado; #18 no
/// está bloqueado por él): mantiene esta feature autocontenida. `bestScore`/
/// `bestStars` son null hasta que exista un ScoreEntry para el nivel.
class LevelProgress extends Equatable {
  final LevelId levelId;
  final bool completed;
  final int? bestScore;
  final int? bestStars;

  LevelProgress({
    required this.levelId,
    required this.completed,
    this.bestScore,
    this.bestStars,
  }) {
    // Invariantes validadas en runtime (no `assert`, que se elimina en release),
    // coherentes con el VO Score/Stars del back (Min(0) / 1..3).
    if (bestScore != null && bestScore! < 0) {
      throw ArgumentError('bestScore must be non-negative, got $bestScore');
    }
    if (bestStars != null && (bestStars! < 1 || bestStars! > 3)) {
      throw ArgumentError('bestStars must be in 1..3, got $bestStars');
    }
  }

  @override
  List<Object?> get props => [levelId, completed, bestScore, bestStars];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/domain/board/value_objects/level_progress_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: analyze + AI_HISTORY + commit**

Añadir entrada a `AI_HISTORY.MD` (ver plantilla en el CLAUDE.md; título "front#18 — LevelProgress VO"). Luego:

```bash
export PATH="/opt/homebrew/bin:$PATH" && flutter analyze lib/domain/board/value_objects/level_progress.dart
git add lib/domain/board/value_objects/level_progress.dart test/domain/board/value_objects/level_progress_test.dart AI_HISTORY.MD
git commit -m "feat(front/domain): add LevelProgress value object for sync

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `ProgressReconciler` domain service

**Files:**
- Create: `lib/domain/board/services/progress_reconciler.dart`
- Test: `test/domain/board/services/progress_reconciler_test.dart`

**Interfaces:**
- Consumes: `LevelProgress`, `LevelId`.
- Produces: `class ProgressReconciler` con
  `List<LevelProgress> reconcile(List<LevelProgress> local, List<LevelProgress> remote)`.
  Regla: une por `levelId.value`; por nivel `completed = local || remote`,
  `bestScore`/`bestStars` = máximo tratando `null` como peor (no-null gana a null).

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/board/services/progress_reconciler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/board/services/progress_reconciler.dart';

LevelProgress lp(String id, bool completed, {int? score, int? stars}) =>
    LevelProgress(levelId: LevelId(id), completed: completed, bestScore: score, bestStars: stars);

LevelProgress pick(List<LevelProgress> list, String id) =>
    list.firstWhere((p) => p.levelId.value == id);

void main() {
  late ProgressReconciler reconciler;
  setUp(() => reconciler = ProgressReconciler());

  group('reconcile', () {
    test('should_keep_higher_score_when_both_sides_have_score', () {
      // Arrange
      final local = [lp('1', true, score: 800, stars: 2)];
      final remote = [lp('1', true, score: 1200, stars: 3)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(pick(merged, '1').bestScore, 1200);
      expect(pick(merged, '1').bestStars, 3);
    });

    test('should_prefer_non_null_score_when_one_side_is_null', () {
      // Arrange
      final local = [lp('1', true)]; // no score
      final remote = [lp('1', true, score: 500, stars: 1)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(pick(merged, '1').bestScore, 500);
      expect(pick(merged, '1').bestStars, 1);
    });

    test('should_mark_completed_when_completed_on_either_side', () {
      // Arrange
      final local = [lp('1', false)];
      final remote = [lp('1', true)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(pick(merged, '1').completed, isTrue);
    });

    test('should_include_levels_present_on_only_one_side', () {
      // Arrange
      final local = [lp('1', true, score: 100)];
      final remote = [lp('2', true, score: 200)];
      // Act
      final merged = reconciler.reconcile(local, remote);
      // Assert
      expect(merged.length, 2);
      expect(pick(merged, '1').bestScore, 100);
      expect(pick(merged, '2').bestScore, 200);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/domain/board/services/progress_reconciler_test.dart`
Expected: FAIL — `progress_reconciler.dart` no existe.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/board/services/progress_reconciler.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/domain/board/services/progress_reconciler_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: analyze + AI_HISTORY + commit**

```bash
export PATH="/opt/homebrew/bin:$PATH" && flutter analyze lib/domain/board/services/progress_reconciler.dart
git add lib/domain/board/services/progress_reconciler.dart test/domain/board/services/progress_reconciler_test.dart AI_HISTORY.MD
git commit -m "feat(front/domain): add ProgressReconciler best-score-wins merge

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Local repo — Hive model fields + `getAll`/`upsertAll`

**Files:**
- Modify: `lib/infrastructure/models/level_progress_hive_model.dart` (añadir fields 3,4)
- Regenerate: `lib/infrastructure/models/level_progress_hive_model.g.dart` (build_runner)
- Modify: `lib/infrastructure/data_sources/local/hive_level_progress_data_source.dart`
- Modify: `lib/domain/board/repositories/i_level_progress_repository.dart` (añadir 2 métodos)
- Modify: `lib/infrastructure/repositories/hive_progress_repository.dart`
- Test: `test/infrastructure/repositories/hive_progress_repository_test.dart` (añadir grupo)

**Interfaces:**
- Consumes: `LevelProgress`, `LevelId`.
- Produces:
  - `ILevelProgressRepository.getAll() → Future<List<LevelProgress>>`
  - `ILevelProgressRepository.upsertAll(List<LevelProgress>) → Future<void>`
  - `HiveLocalDataSource.getAllProgress() → List<LevelProgressHiveModel>`
  - `HiveLocalDataSource.upsertProgress(String levelId, bool completed, int? bestScore, int? bestStars) → Future<void>`
  - `LevelProgressHiveModel` con nuevos campos `int? bestScore` (field 3), `int? bestStars` (field 4).

- [ ] **Step 1: Extend the Hive model**

En `lib/infrastructure/models/level_progress_hive_model.dart`, añadir los campos y ampliar el constructor:

```dart
  @HiveField(2)
  late bool completed;

  @HiveField(3)
  int? bestScore;

  @HiveField(4)
  int? bestStars;

  LevelProgressHiveModel({
    required this.levelId,
    required this.moveCount,
    required this.completed,
    this.bestScore,
    this.bestStars,
  });
```

(Campos aditivos: registros viejos sin fields 3/4 leen `null` — retrocompatible.)

- [ ] **Step 2: Regenerate the Hive adapter**

Run: `export PATH="/opt/homebrew/bin:$PATH" && dart run build_runner build --delete-conflicting-outputs`
Expected: regenera `level_progress_hive_model.g.dart` incluyendo `bestScore`/`bestStars` (grep para confirmar):
`grep -c bestScore lib/infrastructure/models/level_progress_hive_model.g.dart` → ≥ 1.

- [ ] **Step 3: Write the failing test (local getAll/upsertAll)**

Añadir a `test/infrastructure/repositories/hive_progress_repository_test.dart` (el archivo ya declara `@GenerateMocks([HiveLocalDataSource])` y `mockDataSource`/`repository` en setUp):

```dart
  group('getAll', () {
    test('should_map_all_models_to_level_progress_when_present', () async {
      // Arrange
      when(mockDataSource.getAllProgress()).thenReturn([
        LevelProgressHiveModel(
            levelId: '1', moveCount: 5, completed: true, bestScore: 900, bestStars: 3),
        LevelProgressHiveModel(
            levelId: '2', moveCount: 0, completed: false),
      ]);
      // Act
      final result = await repository.getAll();
      // Assert
      expect(result, hasLength(2));
      expect(result.first.levelId, LevelId('1'));
      expect(result.first.bestScore, 900);
      expect(result.first.bestStars, 3);
      expect(result.last.bestScore, isNull);
    });
  });

  group('upsertAll', () {
    test('should_upsert_each_entry_when_saving_merged_progress', () async {
      // Arrange
      when(mockDataSource.upsertProgress(any, any, any, any))
          .thenAnswer((_) async {});
      final progress = [
        LevelProgress(
            levelId: LevelId('1'), completed: true, bestScore: 900, bestStars: 3),
      ];
      // Act
      await repository.upsertAll(progress);
      // Assert
      verify(mockDataSource.upsertProgress('1', true, 900, 3)).called(1);
    });
  });
```

Añadir el import de `LevelProgress` al archivo de test:
`import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';`

- [ ] **Step 4: Run test to verify it fails**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/infrastructure/repositories/hive_progress_repository_test.dart`
Expected: FAIL — `getAll`/`upsertAll` no existen en el repo y `getAllProgress`/`upsertProgress` no están en el mock (método no definido).

- [ ] **Step 5: Add datasource methods**

En `lib/infrastructure/data_sources/local/hive_level_progress_data_source.dart`, añadir:

```dart
  List<LevelProgressHiveModel> getAllProgress() => _box.values.toList();

  /// Upsert del registro completo (incluye score/estrellas). Preserva
  /// moveCount previo si existe; usa 0 para registros nuevos (el sync no
  /// transporta moveCount, solo completado + best score/estrellas).
  Future<void> upsertProgress(
      String levelId, bool completed, int? bestScore, int? bestStars) async {
    final existing = _box.get(levelId);
    if (existing != null) {
      existing.completed = completed;
      existing.bestScore = bestScore;
      existing.bestStars = bestStars;
      await existing.save();
    } else {
      await _box.put(
        levelId,
        LevelProgressHiveModel(
          levelId: levelId,
          moveCount: 0,
          completed: completed,
          bestScore: bestScore,
          bestStars: bestStars,
        ),
      );
    }
  }
```

- [ ] **Step 6: Extend the port**

En `lib/domain/board/repositories/i_level_progress_repository.dart`, añadir el import y los dos métodos:

```dart
import '../value_objects/level_id.dart';
import '../value_objects/level_progress.dart';
import '../../game_core/value_objects/move_count.dart';

abstract interface class ILevelProgressRepository {
  Future<MoveCount?> getProgress(LevelId levelId);
  Future<void> saveProgress(LevelId levelId, MoveCount moves);
  Future<void> markCompleted(LevelId levelId);
  Future<bool> isCompleted(LevelId levelId);

  /// Todo el progreso persistido, para reconciliar con el remoto (front#18).
  Future<List<LevelProgress>> getAll();

  /// Persiste el set de progreso ya reconciliado (front#18).
  Future<void> upsertAll(List<LevelProgress> progress);
}
```

- [ ] **Step 7: Implement in HiveProgressRepository**

En `lib/infrastructure/repositories/hive_progress_repository.dart`, añadir el import de `LevelProgress` y los métodos:

```dart
  @override
  Future<List<LevelProgress>> getAll() async {
    return _dataSource.getAllProgress().map((m) {
      return LevelProgress(
        levelId: LevelId(m.levelId),
        completed: m.completed,
        bestScore: m.bestScore,
        bestStars: m.bestStars,
      );
    }).toList();
  }

  @override
  Future<void> upsertAll(List<LevelProgress> progress) async {
    for (final p in progress) {
      await _dataSource.upsertProgress(
          p.levelId.value, p.completed, p.bestScore, p.bestStars);
    }
  }
```

- [ ] **Step 8: Regenerate mocks + run test to verify it passes**

Run: `export PATH="/opt/homebrew/bin:$PATH" && dart run build_runner build --delete-conflicting-outputs && flutter test test/infrastructure/repositories/hive_progress_repository_test.dart`
Expected: PASS (grupos previos + getAll + upsertAll).

- [ ] **Step 9: analyze + AI_HISTORY + commit**

```bash
export PATH="/opt/homebrew/bin:$PATH" && flutter analyze lib/domain/board/repositories/i_level_progress_repository.dart lib/infrastructure
git add lib/infrastructure/models/level_progress_hive_model.dart lib/infrastructure/models/level_progress_hive_model.g.dart lib/infrastructure/data_sources/local/hive_level_progress_data_source.dart lib/domain/board/repositories/i_level_progress_repository.dart lib/infrastructure/repositories/hive_progress_repository.dart test/infrastructure/repositories/hive_progress_repository_test.dart test/infrastructure/repositories/hive_progress_repository_test.mocks.dart AI_HISTORY.MD
git commit -m "feat(front/infra): persist bestScore/bestStars and expose getAll/upsertAll

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Remote progress port + Dio repo

**Files:**
- Create: `lib/domain/board/repositories/i_remote_progress_repository.dart`
- Create: `lib/infrastructure/data_sources/remote/remote_progress_data_source.dart`
- Create: `lib/infrastructure/repositories/remote_progress_repository.dart`
- Test: `test/infrastructure/repositories/remote_progress_repository_test.dart`

**Interfaces:**
- Consumes: `LevelProgress`, `LevelId`.
- Produces:
  - `abstract interface class IRemoteProgressRepository` con
    `Future<List<LevelProgress>> pull();` y
    `Future<List<LevelProgress>> push(List<LevelProgress> progress);`
  - `RemoteProgressDataSource(Dio)` con
    `Future<List<dynamic>> getProgress()` y
    `Future<List<dynamic>> postProgress(List<Map<String, dynamic>> levels)`.
  - `RemoteProgressRepository(RemoteProgressDataSource)` implementa `IRemoteProgressRepository`.

- [ ] **Step 1: Define the port**

```dart
// lib/domain/board/repositories/i_remote_progress_repository.dart
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
```

- [ ] **Step 2: Write the failing test (repo with mocked datasource)**

```dart
// test/infrastructure/repositories/remote_progress_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/remote_progress_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_progress_repository.dart';

import 'remote_progress_repository_test.mocks.dart';

@GenerateMocks([RemoteProgressDataSource])
void main() {
  late MockRemoteProgressDataSource mockDataSource;
  late RemoteProgressRepository repository;

  setUp(() {
    mockDataSource = MockRemoteProgressDataSource();
    repository = RemoteProgressRepository(mockDataSource);
  });

  group('pull', () {
    test('should_map_backend_rows_to_level_progress_when_pulling', () async {
      // Arrange
      when(mockDataSource.getProgress()).thenAnswer((_) async => [
            {'levelId': '1', 'completed': true, 'bestScore': 1200, 'bestStars': 3},
            {'levelId': '2', 'completed': false, 'bestScore': null, 'bestStars': null},
          ]);
      // Act
      final result = await repository.pull();
      // Assert
      expect(result, hasLength(2));
      expect(result.first.levelId, LevelId('1'));
      expect(result.first.bestScore, 1200);
      expect(result.last.bestScore, isNull);
      expect(result.last.completed, isFalse);
    });
  });

  group('push', () {
    test('should_serialize_progress_and_map_merged_response_when_pushing', () async {
      // Arrange
      when(mockDataSource.postProgress(any)).thenAnswer((_) async => [
            {'levelId': '1', 'completed': true, 'bestScore': 1200, 'bestStars': 3},
          ]);
      final progress = [
        LevelProgress(
            levelId: LevelId('1'), completed: true, bestScore: 1200, bestStars: 3),
        LevelProgress(levelId: LevelId('2'), completed: true),
      ];
      // Act
      final result = await repository.push(progress);
      // Assert
      final captured = verify(mockDataSource.postProgress(captureAny)).captured.single
          as List<Map<String, dynamic>>;
      expect(captured.first,
          {'levelId': '1', 'completed': true, 'bestScore': 1200, 'bestStars': 3});
      // null score/stars se omiten del payload (campos opcionales del back)
      expect(captured.last, {'levelId': '2', 'completed': true});
      expect(result.single.levelId, LevelId('1'));
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/infrastructure/repositories/remote_progress_repository_test.dart`
Expected: FAIL — datasource/repo no existen y el mock no está generado.

- [ ] **Step 4: Implement the datasource**

```dart
// lib/infrastructure/data_sources/remote/remote_progress_data_source.dart
import 'package:dio/dio.dart';

/// Data source remoto de progreso: traduce a llamadas HTTP contra `/progress`
/// del back y devuelve el JSON crudo. No mapea errores (tarea del repo adapter);
/// propaga DioException hacia arriba. Usa el Dio compuesto en main (con el
/// AuthTokenInterceptor).
class RemoteProgressDataSource {
  final Dio _dio;
  RemoteProgressDataSource(this._dio);

  Future<List<dynamic>> getProgress() async {
    final res = await _dio.get('/progress');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> postProgress(List<Map<String, dynamic>> levels) async {
    final res = await _dio.post('/progress', data: {'levels': levels});
    return res.data as List<dynamic>;
  }
}
```

- [ ] **Step 5: Implement the repository**

```dart
// lib/infrastructure/repositories/remote_progress_repository.dart
import '../../domain/board/repositories/i_remote_progress_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/board/value_objects/level_progress.dart';
import '../data_sources/remote/remote_progress_data_source.dart';

/// Adapter: implementa el puerto remoto mapeando `LevelProgress` <-> el shape
/// JSON de `/progress` (back#8). Los null de score/estrellas se omiten en el
/// push (campos opcionales del back) y se leen como null en el pull.
class RemoteProgressRepository implements IRemoteProgressRepository {
  final RemoteProgressDataSource _dataSource;
  RemoteProgressRepository(this._dataSource);

  @override
  Future<List<LevelProgress>> pull() async {
    final rows = await _dataSource.getProgress();
    return rows.map(_fromJson).toList();
  }

  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async {
    final rows = await _dataSource.postProgress(progress.map(_toJson).toList());
    return rows.map(_fromJson).toList();
  }

  LevelProgress _fromJson(dynamic row) {
    final m = row as Map;
    return LevelProgress(
      levelId: LevelId(m['levelId'] as String),
      completed: m['completed'] as bool,
      bestScore: m['bestScore'] as int?,
      bestStars: m['bestStars'] as int?,
    );
  }

  Map<String, dynamic> _toJson(LevelProgress p) => {
        'levelId': p.levelId.value,
        'completed': p.completed,
        if (p.bestScore != null) 'bestScore': p.bestScore,
        if (p.bestStars != null) 'bestStars': p.bestStars,
      };
}
```

- [ ] **Step 6: Regenerate mocks + run test to verify it passes**

Run: `export PATH="/opt/homebrew/bin:$PATH" && dart run build_runner build --delete-conflicting-outputs && flutter test test/infrastructure/repositories/remote_progress_repository_test.dart`
Expected: PASS (pull + push).

- [ ] **Step 7: analyze + AI_HISTORY + commit**

```bash
export PATH="/opt/homebrew/bin:$PATH" && flutter analyze lib/domain/board/repositories/i_remote_progress_repository.dart lib/infrastructure/data_sources/remote/remote_progress_data_source.dart lib/infrastructure/repositories/remote_progress_repository.dart
git add lib/domain/board/repositories/i_remote_progress_repository.dart lib/infrastructure/data_sources/remote/remote_progress_data_source.dart lib/infrastructure/repositories/remote_progress_repository.dart test/infrastructure/repositories/remote_progress_repository_test.dart test/infrastructure/repositories/remote_progress_repository_test.mocks.dart AI_HISTORY.MD
git commit -m "feat(front/infra): add Dio remote progress repository (push/pull /progress)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `SyncProgressUseCase`

**Files:**
- Create: `lib/application/use_cases/sync_progress_use_case.dart`
- Test: `test/application/use_cases/sync_progress_use_case_test.dart`

**Interfaces:**
- Consumes: `IRemoteProgressRepository`, `ILevelProgressRepository`, `ProgressReconciler`, `ILoggerService`, `LevelProgress`.
- Produces: `class SyncProgressUseCase` con constructor
  `SyncProgressUseCase(IRemoteProgressRepository remote, ILevelProgressRepository local, ProgressReconciler reconciler, ILoggerService logger)`
  y `Future<void> execute()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/application/use_cases/sync_progress_use_case_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/services/progress_reconciler.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/application/use_cases/sync_progress_use_case.dart';

import 'sync_progress_use_case_test.mocks.dart';

@GenerateMocks([
  IRemoteProgressRepository,
  ILevelProgressRepository,
  ILoggerService,
])
void main() {
  late MockIRemoteProgressRepository remote;
  late MockILevelProgressRepository local;
  late MockILoggerService logger;
  late SyncProgressUseCase useCase;

  setUp(() {
    remote = MockIRemoteProgressRepository();
    local = MockILevelProgressRepository();
    logger = MockILoggerService();
    useCase = SyncProgressUseCase(remote, local, ProgressReconciler(), logger);
  });

  test('should_pull_reconcile_push_and_persist_when_syncing', () async {
    // Arrange
    when(remote.pull()).thenAnswer((_) async =>
        [LevelProgress(levelId: LevelId('1'), completed: true, bestScore: 500)]);
    when(local.getAll()).thenAnswer((_) async =>
        [LevelProgress(levelId: LevelId('1'), completed: false, bestScore: 900)]);
    when(remote.push(any)).thenAnswer((inv) async =>
        inv.positionalArguments.first as List<LevelProgress>);
    when(local.upsertAll(any)).thenAnswer((_) async {});

    // Act
    await useCase.execute();

    // Assert — best score gana (900) y se pushea + persiste el merge
    final pushed =
        verify(remote.push(captureAny)).captured.single as List<LevelProgress>;
    expect(pushed.single.bestScore, 900);
    final persisted =
        verify(local.upsertAll(captureAny)).captured.single as List<LevelProgress>;
    expect(persisted.single.bestScore, 900);
  });

  test('should_not_throw_and_log_error_when_network_fails', () async {
    // Arrange
    when(remote.pull()).thenThrow(Exception('network down'));

    // Act
    Future<void> act() => useCase.execute();

    // Assert — el fallo de red no rompe el flujo; se loguea el error
    await expectLater(act(), completes);
    verify(logger.error(any, any, any)).called(1);
    verifyNever(local.upsertAll(any));
  });
}
```

- [ ] **Step 2: Regenerate mocks + run test to verify it fails**

Run: `export PATH="/opt/homebrew/bin:$PATH" && dart run build_runner build --delete-conflicting-outputs && flutter test test/application/use_cases/sync_progress_use_case_test.dart`
Expected: FAIL — `sync_progress_use_case.dart` no existe.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/application/use_cases/sync_progress_use_case.dart
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
      await _local.upsertAll(merged);
      _logger.log('Progress synced: ${merged.length} level(s)', _ctx);
    } catch (e) {
      _logger.error('Progress sync failed', _ctx, e);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/application/use_cases/sync_progress_use_case_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: analyze + AI_HISTORY + commit**

```bash
export PATH="/opt/homebrew/bin:$PATH" && flutter analyze lib/application/use_cases/sync_progress_use_case.dart
git add lib/application/use_cases/sync_progress_use_case.dart test/application/use_cases/sync_progress_use_case_test.dart test/application/use_cases/sync_progress_use_case_test.mocks.dart AI_HISTORY.MD
git commit -m "feat(front/application): add SyncProgressUseCase orchestrating pull/reconcile/push

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Wiring — providers + AuthGate listener

**Files:**
- Modify: `lib/application/providers/dependency_providers.dart`
- Modify: `lib/main.dart` (override del provider remoto con el Dio compuesto)
- Modify: `lib/core/auth/auth_gate.dart` (listener)
- Test: `test/application/providers/sync_progress_provider_test.dart` (composición)

**Interfaces:**
- Consumes: `SyncProgressUseCase`, `IRemoteProgressRepository`, `RemoteProgressRepository`, `RemoteProgressDataSource`, `levelProgressRepositoryProvider`, `loggerServiceProvider`, `authControllerProvider`, `Authenticated`.
- Produces:
  - `remoteProgressRepositoryProvider` (Provider<IRemoteProgressRepository>, override en main)
  - `progressReconcilerProvider` (Provider<ProgressReconciler>)
  - `syncProgressUseCaseProvider` (Provider<SyncProgressUseCase>)

- [ ] **Step 1: Write the failing composition test**

```dart
// test/application/providers/sync_progress_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_arrow_maze/application/providers/dependency_providers.dart';
import 'package:flutter_arrow_maze/application/use_cases/sync_progress_use_case.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';

class _FakeRemote implements IRemoteProgressRepository {
  @override
  Future<List<LevelProgress>> pull() async => [];
  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async => progress;
}

void main() {
  test('should_compose_SyncProgressUseCase_when_remote_provider_overridden', () {
    // Arrange
    final container = ProviderContainer(overrides: [
      remoteProgressRepositoryProvider.overrideWithValue(_FakeRemote()),
    ]);
    addTearDown(container.dispose);
    // Act
    final useCase = container.read(syncProgressUseCaseProvider);
    // Assert
    expect(useCase, isA<SyncProgressUseCase>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/application/providers/sync_progress_provider_test.dart`
Expected: FAIL — los providers no existen en `dependency_providers.dart`.

- [ ] **Step 3: Add providers**

En `lib/application/providers/dependency_providers.dart` añadir imports y providers:

```dart
import '../../domain/board/repositories/i_remote_progress_repository.dart';
import '../../domain/board/services/progress_reconciler.dart';
import '../use_cases/sync_progress_use_case.dart';
```

```dart
// front#18: el repo remoto necesita el Dio compuesto en main (con el token
// interceptor); por eso su default falla y main.dart lo sobreescribe (DIP),
// igual que authRepositoryProvider.
final remoteProgressRepositoryProvider = Provider<IRemoteProgressRepository>(
  (_) => throw UnimplementedError(
    'remoteProgressRepositoryProvider must be overridden in main with composed Dio',
  ),
);

final progressReconcilerProvider = Provider<ProgressReconciler>(
  (_) => ProgressReconciler(),
);

final syncProgressUseCaseProvider = Provider<SyncProgressUseCase>(
  (ref) => SyncProgressUseCase(
    ref.watch(remoteProgressRepositoryProvider),
    ref.watch(levelProgressRepositoryProvider),
    ref.watch(progressReconcilerProvider),
    ref.watch(loggerServiceProvider),
  ),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test test/application/providers/sync_progress_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Override the remote provider in main.dart**

En `lib/main.dart`, añadir imports:

```dart
import 'application/providers/dependency_providers.dart';
import 'infrastructure/data_sources/remote/remote_progress_data_source.dart';
import 'infrastructure/repositories/remote_progress_repository.dart';
```

Y en la lista `overrides` del `ProviderScope` (junto a `authRepositoryProvider.overrideWithValue(...)`) añadir:

```dart
        // front#18: repo remoto de progreso compuesto con el mismo Dio (token
        // interceptor). Las capas internas solo conocen el puerto.
        remoteProgressRepositoryProvider.overrideWithValue(
          RemoteProgressRepository(RemoteProgressDataSource(dio)),
        ),
```

- [ ] **Step 6: Add the AuthGate listener**

En `lib/core/auth/auth_gate.dart`, añadir imports y el `ref.listen` dentro de `build` (antes del `return`):

```dart
import '../../application/providers/dependency_providers.dart';
```

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // front#18: al pasar a Authenticated (login o auto-login), dispara el sync
    // de progreso una sola vez por transición. Fire-and-forget: el use case
    // maneja el error de red internamente (no rompe el guard).
    ref.listen(authControllerProvider, (prev, next) {
      final wasAuth = prev?.valueOrNull is Authenticated;
      final isAuth = next.valueOrNull is Authenticated;
      if (isAuth && !wasAuth) {
        ref.read(syncProgressUseCaseProvider).execute();
      }
    });

    final auth = ref.watch(authControllerProvider);
    // ... (resto sin cambios)
```

- [ ] **Step 7: analyze the wired files**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter analyze lib/application/providers/dependency_providers.dart lib/main.dart lib/core/auth/auth_gate.dart`
Expected: No issues found.

- [ ] **Step 8: Full test suite + AI_HISTORY + commit**

Run: `export PATH="/opt/homebrew/bin:$PATH" && flutter test`
Expected: toda la suite verde.

```bash
git add lib/application/providers/dependency_providers.dart lib/main.dart lib/core/auth/auth_gate.dart test/application/providers/sync_progress_provider_test.dart AI_HISTORY.MD
git commit -m "feat(front): trigger progress sync on authentication

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: README + end-to-end verification

**Files:**
- Modify: `MazePruebaFront/README.md` (documentar el sync de progreso si toca API pública/arquitectura)

- [ ] **Step 1: Update README**

Añadir a la sección de arquitectura/infra del README una línea sobre el sync de progreso: puerto `IRemoteProgressRepository` + `SyncProgressUseCase`, disparado al autenticarse, reconcilia con `/progress` (best score gana). Nota de la limitación heredada `remember:false` (pendiente de front#16).

- [ ] **Step 2: End-to-end verification (real)**

Con el back corriendo (`http://10.0.2.2:3000` desde el emulador Android) y un usuario **con "recordarme" marcado**:
- Iniciar sesión → observar en el back un `GET /progress` y un `POST /progress` firmados (header `Authorization`).
- Verificar que el progreso local persiste el merge (re-login no degrada el best score).

Nota: con `remember:false` el interceptor aún no firma (gap de front#16); documentado, fuera de alcance aquí.

- [ ] **Step 3: analyze + commit README**

```bash
export PATH="/opt/homebrew/bin:$PATH" && flutter analyze
git add README.md AI_HISTORY.MD
git commit -m "docs(front): document progress sync in README

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Pre-PR

- [ ] `git fetch origin && git rebase origin/main` — resolver conflictos si `main` avanzó (p. ej. si front#12/#16 mergearon y tocaron el Hive model o el interceptor). Re-correr `dart run build_runner build --delete-conflicting-outputs` tras el rebase si cambió el model.
- [ ] `export PATH="/opt/homebrew/bin:$PATH" && flutter analyze && flutter test` — todo verde.
- [ ] Abrir PR con `gh api` (no `gh pr create`) por el `#` en el nombre de rama `feat/#18-progress-sync`.
