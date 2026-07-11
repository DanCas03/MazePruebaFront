# front#8 — Remote Levels Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the front's campaign play the **official levels** served by `MazePruebaBack` (`GET /levels`, `GET /levels/:id`) instead of generating boards locally — robustly, with offline cache, load/error states, and a "next level" dictated by the back's Catálogo order.

**Architecture:** A new domain contract (`Level` VO, `LevelFailure` sealed, `ILevelRepository` port) is implemented by an infrastructure adapter (`RemoteLevelRepository`) using a network-first-with-cache strategy over a Dio data source + a Hive cache + a strict JSON decoder. The application layer exposes a reactive `levelCatalogProvider` (with opportunistic background prefetch) and rewires `GameController.loadLevel` from synchronous-generative to asynchronous-remote. Presentation consumes only these providers: the level grid, victory "next", and game error branch are driven by the Catálogo and `LevelFailure`.

**Tech Stack:** Flutter/Dart · Riverpod (`AsyncNotifier`, manual providers) · Dio · Hive CE · dartz `Either` · Equatable · mockito (codegen) · `flutter gen-l10n`.

## Global Constraints

Every task's requirements implicitly include this section. Values are copied verbatim from the spec (`docs/superpowers/specs/2026-07-11-front8-remote-levels-integration-design.md`, commit `917fd4e`) and `.claude/CLAUDE.md`.

- **Branch:** `feat/#8-dio-level-dto-mapper` — every fragment commits here (this is a git-independent repo; run all `git`/`flutter`/`dart` commands from `MazePruebaFront/`).
- **Layering (Clean Mobile Architecture):** `domain/` is pure Dart (no Flutter, no external packages except `equatable`/`dartz` where already used). `application/` may import `domain/` and `core/aspects/` (ports) — **never** `presentation/` or `infrastructure/`. `presentation/` consumes only `application/` providers (existing practice: domain VOs like `LevelId` may be named as route args). `infrastructure/` implements `application`/`domain` ports; **`DioException` dies in the repo** — no HTTP type leaks upward.
- **SOLID / DIP:** business code depends on abstractions (`ILevelRepository`, `ILoggerService`); concrete impls are injected from `main.dart`.
- **AOP:** logging goes through the injected `ILoggerService` (`log`/`warn`/`error`). **Never** `print`.
- **Tests (AAA):** every production unit has unit tests, `group(...)` + `test('should_..._when_...', () {...})` with `// Arrange // Act // Assert` comments. Mock external dependencies to isolate the unit. **Test tasks are written as prompts for a `qa` subagent** (arrowmaze-qa skill / qa-engineer role), never as inline test code in this plan (explicit user preference).
- **Package import prefix in tests:** `package:flutter_arrow_maze/...`.
- **No new dependencies:** all required packages are already in `pubspec.yaml`.
- **l10n:** add keys to **both** `lib/l10n/app_en.arb` (template) **and** `lib/l10n/app_es.arb`, then run `flutter gen-l10n`. The generated `app_localizations*.dart` is **not** versioned (regenerated in build/CI); commit only the `.arb` changes.
- **Mocks:** annotate with `@GenerateMocks([...])` and generate with `dart run build_runner build --delete-conflicting-outputs`. The generated `*.mocks.dart` **is** committed (matches existing tests).
- **Per-fragment housekeeping:** each fragment = one Conventional Commit (`<tipo>(<ámbito>): <desc en presente imperativo>`) + one `AI_HISTORY.MD` entry (format below). Do **not** bundle multiple fragments in one commit.
- **AI_HISTORY entry skeleton** (append to `MazePruebaFront/AI_HISTORY.MD`, `NNN` = next number):

  ```
  ## Entrada NNN — <Título del fragmento>

  **Fecha:** 2026-07-11
  **Tarea o problema abordado:** <qué resuelve el fragmento>
  **Herramienta de IA utilizada:** Claude Code (Opus 4.8)
  **Prompt o instrucción proporcionada:** > "Ejecuta la Task N del plan front#8 remote levels."
  **Resultado obtenido:** <archivos creados/modificados, decisiones clave>
  **Modificaciones realizadas por el equipo:** (completar manualmente)
  ```

- **Definition of Done (per fragment):** `flutter analyze` clean for touched files + the fragment's test suite green. **Final DoD (Task 11):** whole-project `flutter analyze` clean + full `flutter test` green.

---

## File Structure

New files (one clear responsibility each), grouped by layer:

**domain/** (pure Dart)
- `lib/domain/board/entities/level.dart` — `Level` VO: `LevelId id`, `ArrowBoard board`, `int? timeLimitSec`; invariants in ctor.
- `lib/domain/board/failures/level_failure.dart` — `sealed LevelFailure` (Equatable): `LevelNotFound(id)`, `LevelUnavailable`, `LevelCorrupted(reason)`.
- `lib/domain/board/repositories/i_level_repository.dart` — port: `listLevelIds()`, `getLevel(id)`.
- `lib/domain/core/exceptions/invalid_level_exception.dart` — `Level` invariant violation (domain exception).

**infrastructure/**
- `lib/infrastructure/serialization/level_json_decoder.dart` — strict wire-JSON → `Level` (inverse of existing `LevelJsonEncoder`).
- `lib/infrastructure/data_sources/remote/level_remote_data_source.dart` — raw `GET /levels`, `GET /levels/:id`.
- `lib/infrastructure/data_sources/local/level_cache_data_source.dart` — Hive `levels_cache` box wrapper (raw JSON + catalog).
- `lib/infrastructure/repositories/remote_level_repository.dart` — `ILevelRepository` impl, network-first + cache; `DioException` dies here.

**application/**
- `lib/application/providers/level_catalog_provider.dart` — `levelCatalogProvider` (`AsyncNotifier<List<LevelId>>`) + background prefetch.

Modified files:
- `lib/application/state/game_controller.dart` — `loadLevel` async-remote; restart without refetch.
- `lib/presentation/providers/dependency_providers.dart` — add `levelRepositoryProvider` (throw-default seam).
- `lib/main.dart` — open `levels_cache` box; compose `RemoteLevelRepository`; override `levelRepositoryProvider`, `gameControllerProvider` (new dep), `levelCatalogProvider`; drop `GraphBoardGenerator` from the game override.
- `lib/presentation/level_selection/level_selection_screen.dart` — `ConsumerWidget` driven by `levelCatalogProvider`.
- `lib/presentation/level_selection/victory_screen.dart` — `ConsumerWidget`; "next" from Catálogo; last-level copy.
- `lib/presentation/game/screens/game_screen.dart` — error branch discriminates `LevelFailure`.
- `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` — new keys (added by the presentation fragments that consume them).
- `MazePruebaFront/README.md` — campaign is now remote (Task 11).

**Explicitly NOT touched** (spec §8 no-objetivos): `LevelBlueprint`, `GraphBoardGenerator`, `ILevelGenerator` and their tests are **kept** (front#36 base); the generator is only **unwired** from `GameController`. No `LevelId.next()`, no `LevelId.number` fix. No cache TTL. No unlock system. No migration of local progress saved under ids `'1'..'12'`.

**Cross-fragment note:** because this is a cross-cutting swap, the running app is only fully self-consistent after Task 10. Each fragment still **compiles** and passes **its own** suite (the per-fragment DoD); whole-app consistency and the full green suite are verified in Task 11. Order is fixed: domain → infra → application → app/DI rewire → presentation → housekeeping.

---

### Task 1: `Level` value object + `InvalidLevelException`

**Files:**
- Create: `lib/domain/core/exceptions/invalid_level_exception.dart`
- Create: `lib/domain/board/entities/level.dart`
- Test: `test/domain/board/entities/level_test.dart`

**Interfaces:**
- Consumes: `ArrowBoard` (`lib/domain/arrows/entities/arrow_board.dart`, ctor `ArrowBoard({required List<Arrow> arrows, required int cols, required int rows})`, exposes `List<Arrow> arrows`); `LevelId` (`lib/domain/board/value_objects/level_id.dart`); `DomainException` (`lib/domain/core/exceptions/domain_exception.dart`, ctor `const DomainException(String message)`).
- Produces: `class Level extends Equatable` with ctor `Level({required LevelId id, required ArrowBoard board, int? timeLimitSec})` and fields `LevelId id`, `ArrowBoard board`, `int? timeLimitSec`. `class InvalidLevelException extends DomainException`.

- [ ] **Step 1: Create the domain exception**

`lib/domain/core/exceptions/invalid_level_exception.dart`:

```dart
import 'domain_exception.dart';

/// Se lanza cuando un [Level] viola una invariante de dominio (tablero sin
/// flechas, o timeLimitSec <= 0). El decoder de infraestructura la traduce a
/// FormatException y, de ahí, el repo a LevelCorrupted.
class InvalidLevelException extends DomainException {
  const InvalidLevelException(super.message);
}
```

- [ ] **Step 2: Create the `Level` VO**

`lib/domain/board/entities/level.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../arrows/entities/arrow_board.dart';
import '../../core/exceptions/invalid_level_exception.dart';
import '../value_objects/level_id.dart';

/// Nivel oficial de la campaña, servido por el back (wire contract, CONTEXT-MAP).
/// VO inmutable: identidad ([id]), tablero jugable ([board]) y límite de tiempo
/// opcional ([timeLimitSec], segundos). Invariantes en el constructor: un nivel
/// oficial vacío no es jugable (board con >= 1 flecha) y, si hay límite, debe
/// ser > 0. Su violación es un dato corrupto → excepción de dominio.
class Level extends Equatable {
  final LevelId id;
  final ArrowBoard board;
  final int? timeLimitSec;

  Level({
    required this.id,
    required this.board,
    this.timeLimitSec,
  }) {
    if (board.arrows.isEmpty) {
      throw const InvalidLevelException('a level must have at least one arrow');
    }
    final limit = timeLimitSec;
    if (limit != null && limit <= 0) {
      throw InvalidLevelException('timeLimitSec must be > 0, got $limit');
    }
  }

  @override
  List<Object?> get props => [id, board, timeLimitSec];
}
```

- [ ] **Step 3: Write the tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill (qa-engineer role) and the following prompt:

> Write unit tests for the `Level` value object at `test/domain/board/entities/level_test.dart` in the `flutter_arrow_maze` project (create the directory). Follow AAA with `group('Level', ...)` and `should_..._when_...` names; imports use `package:flutter_arrow_maze/...`. Under test: `lib/domain/board/entities/level.dart` (ctor `Level({required LevelId id, required ArrowBoard board, int? timeLimitSec})`). Build boards with `ArrowBoard(arrows: [...], cols: c, rows: r)` and arrows with `Arrow(id: ArrowId('a1'), cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)], headDirection: Direction.right)` (imports: `domain/arrows/entities/arrow.dart`, `arrow_board.dart`, `domain/arrows/value_objects/arrow_id.dart`, `domain/game_core/value_objects/position.dart`, `direction.dart`, `domain/board/value_objects/level_id.dart`). Cover: (1) constructs and exposes `id`/`board`/`timeLimitSec` when given a non-empty board and a positive limit; (2) constructs with `timeLimitSec` null (no limit); (3) throws `InvalidLevelException` when `board.arrows` is empty (`ArrowBoard(arrows: const [], cols: 4, rows: 4)`) — assert `throwsA(isA<InvalidLevelException>())` (import `domain/core/exceptions/invalid_level_exception.dart`); (4) throws `InvalidLevelException` when `timeLimitSec == 0` and when `timeLimitSec < 0`; (5) value equality: two `Level`s with equal id+board+timeLimitSec are `==` and unequal when any differs (Equatable). Run `flutter test test/domain/board/entities/level_test.dart` and confirm green. Return only a short summary + the test file path.

- [ ] **Step 4: Verify analyze + tests**

Run: `flutter analyze lib/domain/board/entities/level.dart lib/domain/core/exceptions/invalid_level_exception.dart test/domain/board/entities/level_test.dart`
Expected: `No issues found!`
Run: `flutter test test/domain/board/entities/level_test.dart`
Expected: all tests pass.

- [ ] **Step 5: AI_HISTORY + commit**

Append an AI_HISTORY entry (skeleton in Global Constraints), title `Level VO + InvalidLevelException (front#8)`. Then:

```bash
git add lib/domain/board/entities/level.dart lib/domain/core/exceptions/invalid_level_exception.dart test/domain/board/entities/level_test.dart AI_HISTORY.MD
git commit -m "feat(domain): add Level value object with invariants"
```

---

### Task 2: `LevelFailure` sealed hierarchy + `ILevelRepository` port

**Files:**
- Create: `lib/domain/board/failures/level_failure.dart`
- Create: `lib/domain/board/repositories/i_level_repository.dart`
- Test: `test/domain/board/failures/level_failure_test.dart`

**Interfaces:**
- Consumes: `LevelId`; `Level` (Task 1); `Either` from `package:dartz/dartz.dart`.
- Produces: `sealed class LevelFailure extends Equatable { String get message; }` with `LevelNotFound(LevelId id)`, `LevelUnavailable()`, `LevelCorrupted(String reason)`. `abstract interface class ILevelRepository` with `Future<Either<LevelFailure, List<LevelId>>> listLevelIds()` and `Future<Either<LevelFailure, Level>> getLevel(LevelId id)`.

- [ ] **Step 1: Create `LevelFailure`**

`lib/domain/board/failures/level_failure.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../value_objects/level_id.dart';

/// Fallos esperados al cargar niveles remotos, como jerarquía sellada para que
/// la UI haga pattern matching exhaustivo (espejo de AuthFailure). Equatable
/// para comparar fallos con datos (id/reason) en los tests. `message` es para
/// logging/diagnóstico; la UI mapea cada caso a su copy localizada (l10n).
sealed class LevelFailure extends Equatable {
  const LevelFailure();
  String get message;
}

/// 404 del back: el nivel no existe. El back es autoridad sobre la existencia,
/// así que el repo no consulta la caché para este caso.
class LevelNotFound extends LevelFailure {
  final LevelId id;
  const LevelNotFound(this.id);

  @override
  String get message => 'Level not found: ${id.value}';

  @override
  List<Object?> get props => [id];
}

/// Fallo de red (o servidor) SIN copia en caché: el nivel no puede jugarse ahora.
class LevelUnavailable extends LevelFailure {
  const LevelUnavailable();

  @override
  String get message => 'Level unavailable offline';

  @override
  List<Object?> get props => const [];
}

/// El JSON (de red o de caché) no cumple el wire contract: dato corrupto.
class LevelCorrupted extends LevelFailure {
  final String reason;
  const LevelCorrupted(this.reason);

  @override
  String get message => 'Level data corrupted: $reason';

  @override
  List<Object?> get props => [reason];
}
```

- [ ] **Step 2: Create the port**

`lib/domain/board/repositories/i_level_repository.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../entities/level.dart';
import '../failures/level_failure.dart';
import '../value_objects/level_id.dart';

/// Puerto (DIP) de acceso a los niveles oficiales de la campaña. La app depende
/// de esta abstracción; la impl remota (con caché) vive en infrastructure. El
/// prefetch NO es método del puerto: lo orquesta la capa de aplicación
/// reutilizando [getLevel] (el repo cachea como efecto natural).
abstract interface class ILevelRepository {
  /// Ids del Catálogo en orden de juego (GET /levels).
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds();

  /// Nivel completo por id (GET /levels/:id), network-first con fallback a caché.
  Future<Either<LevelFailure, Level>> getLevel(LevelId id);
}
```

- [ ] **Step 3: Write the tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write unit tests for `LevelFailure` at `test/domain/board/failures/level_failure_test.dart` in `flutter_arrow_maze` (create the directory). AAA, `group('LevelFailure', ...)`, `should_..._when_...`. Under test: `lib/domain/board/failures/level_failure.dart`. Cover: (1) `LevelNotFound` value equality when ids equal and inequality when ids differ (uses `LevelId` from `domain/board/value_objects/level_id.dart`); (2) `LevelUnavailable` instances are `==` (const, empty props); (3) `LevelCorrupted` equality keyed on `reason`; (4) each subtype's `message` getter contains the discriminating datum (`LevelNotFound(LevelId('level-07')).message` contains `level-07`; `LevelCorrupted('bad cells').message` contains `bad cells`); (5) exhaustive `switch` over a `LevelFailure` compiles (the type is sealed) — a small local function `String describe(LevelFailure f) => switch (f) { LevelNotFound() => 'nf', LevelUnavailable() => 'un', LevelCorrupted() => 'co' };` asserted on one instance of each. Run `flutter test test/domain/board/failures/level_failure_test.dart`. The `ILevelRepository` port has no behavior and needs no standalone test (it is exercised by the repo impl in Task 5). Return a short summary + path.

- [ ] **Step 4: Verify analyze + tests**

Run: `flutter analyze lib/domain/board/failures/level_failure.dart lib/domain/board/repositories/i_level_repository.dart test/domain/board/failures/level_failure_test.dart`
Expected: `No issues found!`
Run: `flutter test test/domain/board/failures/level_failure_test.dart` → pass.

- [ ] **Step 5: AI_HISTORY + commit**

AI_HISTORY entry title `LevelFailure sealed + ILevelRepository port (front#8)`. Then:

```bash
git add lib/domain/board/failures/level_failure.dart lib/domain/board/repositories/i_level_repository.dart test/domain/board/failures/level_failure_test.dart AI_HISTORY.MD
git commit -m "feat(domain): add LevelFailure and ILevelRepository port"
```

---

### Task 3: `LevelJsonDecoder` (wire JSON → `Level`)

**Files:**
- Create: `lib/infrastructure/serialization/level_json_decoder.dart`
- Test: `test/infrastructure/serialization/level_json_decoder_test.dart`

**Interfaces:**
- Consumes: `Level` (Task 1); `ArrowBoard`, `Arrow`, `ArrowId`, `Position`, `Direction`; `LevelId`; `DomainException`. The existing `LevelJsonEncoder` (`lib/infrastructure/serialization/level_json_encoder.dart`, `toMap({required String levelId, required ArrowBoard board, int? timeLimitSec})`) is the inverse used by the golden test.
- Produces: `class LevelJsonDecoder { const LevelJsonDecoder(); Level decode(Map<String, Object?> json); }`. Contract: throws **only** `FormatException` on any wire-contract violation (missing/typed-wrong key, unknown `headDir`, empty/malformed `cells`) or domain-invariant violation.

- [ ] **Step 1: Create the decoder**

`lib/infrastructure/serialization/level_json_decoder.dart`:

```dart
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/entities/level.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/core/exceptions/domain_exception.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

/// Parsea el JSON arrow-path del wire contract (CONTEXT-MAP raíz) a un [Level].
/// Inverso de [LevelJsonEncoder]; propiedad golden: encodear el resultado de
/// decodear reproduce el JSON original. ESTRICTO: cualquier desviación del
/// contrato (clave ausente, tipo incorrecto, headDir desconocido, cells vacío o
/// celda malformada) o violación de invariante de dominio lanza [FormatException]
/// con el motivo; el repo la traduce a LevelCorrupted.
class LevelJsonDecoder {
  const LevelJsonDecoder();

  Level decode(Map<String, Object?> json) {
    try {
      return _decodeStrict(json);
    } on DomainException catch (e) {
      // Datos del wire que violan una invariante de dominio = contrato roto.
      throw FormatException('domain invariant violated: ${e.message}');
    }
  }

  Level _decodeStrict(Map<String, Object?> json) {
    final arrows = <Arrow>[
      for (final raw in _list(json, 'arrows')) _arrow(raw),
    ];
    return Level(
      id: LevelId(_string(json, 'levelId')),
      board: ArrowBoard(
        arrows: arrows,
        cols: _int(json, 'cols'),
        rows: _int(json, 'rows'),
      ),
      timeLimitSec: _optionalInt(json, 'timeLimitSec'),
    );
  }

  Arrow _arrow(Object? raw) {
    if (raw is! Map) throw const FormatException('arrow must be an object');
    final map = raw.cast<String, Object?>();
    final id = _string(map, 'id');
    final cells = _list(map, 'cells');
    if (cells.isEmpty) {
      throw FormatException('cells must be non-empty (arrow "$id")');
    }
    return Arrow(
      id: ArrowId(id),
      headDirection: _direction(_string(map, 'headDir')),
      cells: [for (final cell in cells) _position(cell, id)],
    );
  }

  Position _position(Object? cell, String arrowId) {
    if (cell is! List || cell.length != 2) {
      throw FormatException('cell must be a [row, col] pair (arrow "$arrowId")');
    }
    final row = cell[0];
    final col = cell[1];
    if (row is! int || col is! int) {
      throw FormatException('cell coords must be ints (arrow "$arrowId")');
    }
    return Position(row: row, col: col);
  }

  Direction _direction(String headDir) {
    for (final d in Direction.values) {
      if (d.name == headDir) return d;
    }
    throw FormatException('unknown headDir "$headDir"');
  }

  List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('missing or non-list "$key"');
    return value;
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('missing or non-string "$key"');
    return value;
  }

  int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('missing or non-int "$key"');
    return value;
  }

  int? _optionalInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! int) {
      throw FormatException('"$key" must be an int when present');
    }
    return value;
  }
}
```

- [ ] **Step 2: Write the tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write unit tests for `LevelJsonDecoder` at `test/infrastructure/serialization/level_json_decoder_test.dart` in `flutter_arrow_maze`. AAA, `group('LevelJsonDecoder', ...)`, `should_..._when_...`. Under test: `lib/infrastructure/serialization/level_json_decoder.dart` (`const LevelJsonDecoder()`, `Level decode(Map<String, Object?>)`). Define the **canonical wire map** exactly as the CONTEXT-MAP root example:
> ```dart
> final canonical = <String, Object?>{
>   'levelId': 'l-007', 'cols': 8, 'rows': 11, 'timeLimitSec': 90,
>   'arrows': [
>     {'id': 'a1', 'headDir': 'up',    'cells': [[10, 3], [9, 3], [9, 4]]},
>     {'id': 'a2', 'headDir': 'right', 'cells': [[2, 0], [2, 1]]},
>   ],
> };
> ```
> Cover: (1) **golden round-trip** — `final level = decoder.decode(canonical);` then with the existing `LevelJsonEncoder` (`const LevelJsonEncoder()`, import `infrastructure/serialization/level_json_encoder.dart`) assert `encoder.toMap(levelId: level.id.value, board: level.board, timeLimitSec: level.timeLimitSec)` deep-equals `canonical` (use `equals(canonical)`); also assert decoded fields directly: `level.id == LevelId('l-007')`, `board.cols == 8`, `board.rows == 11`, `board.arrows.length == 2`, first arrow `headDirection == Direction.up` with cells `[Position(10,3), Position(9,3), Position(9,4)]`, `level.timeLimitSec == 90`; (2) decodes a level with **no** `timeLimitSec` key → `level.timeLimitSec == null`; (3–7) **corrupt cases each throw `FormatException`** (`expect(() => decoder.decode(bad), throwsFormatException)`), one test each: missing `cols`; `headDir` set to `'sideways'` (unknown); an arrow with empty `cells: []`; a cell that is not a `[row, col]` pair (e.g. `[1, 2, 3]` or `[1]`); a non-int coord (`['x', 2]`); plus a case where `arrows` is `[]` (empty board violates the `Level` invariant → must surface as `FormatException`, not `InvalidLevelException`); plus `timeLimitSec: 0` (invalid limit → `FormatException`). Imports use `package:flutter_arrow_maze/...`. Run `flutter test test/infrastructure/serialization/level_json_decoder_test.dart`. Return a short summary + path.

- [ ] **Step 3: Verify analyze + tests**

Run: `flutter analyze lib/infrastructure/serialization/level_json_decoder.dart test/infrastructure/serialization/level_json_decoder_test.dart` → `No issues found!`
Run: `flutter test test/infrastructure/serialization/level_json_decoder_test.dart` → pass.

- [ ] **Step 4: AI_HISTORY + commit**

AI_HISTORY entry title `LevelJsonDecoder — wire JSON → Level (front#8)`. Then:

```bash
git add lib/infrastructure/serialization/level_json_decoder.dart test/infrastructure/serialization/level_json_decoder_test.dart AI_HISTORY.MD
git commit -m "feat(infra): add LevelJsonDecoder for wire-contract levels"
```

---

### Task 4: `LevelRemoteDataSource`

**Files:**
- Create: `lib/infrastructure/data_sources/remote/level_remote_data_source.dart`
- Test: `test/infrastructure/data_sources/remote/level_remote_data_source_test.dart`

**Interfaces:**
- Consumes: `Dio` (composed in `main`, carries the base URL + auth interceptor).
- Produces: `class LevelRemoteDataSource { LevelRemoteDataSource(Dio); Future<List<dynamic>> fetchLevelIds(); Future<Map<String, dynamic>> fetchLevel(String id); }` — raw JSON, propagates `DioException`, no error mapping, no DTO.

- [ ] **Step 1: Create the data source**

`lib/infrastructure/data_sources/remote/level_remote_data_source.dart`:

```dart
import 'package:dio/dio.dart';

/// Data source remoto de niveles: traduce a `GET /levels` y `GET /levels/:id`
/// (back#5, público) y devuelve el JSON crudo. No mapea errores (tarea del repo
/// adapter); propaga DioException hacia arriba. Sin clase DTO: el decoder es la
/// única fuente de verdad del parseo. Usa el Dio compuesto en main.
class LevelRemoteDataSource {
  final Dio _dio;
  LevelRemoteDataSource(this._dio);

  Future<List<dynamic>> fetchLevelIds() async {
    final res = await _dio.get('/levels');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchLevel(String id) async {
    final res = await _dio.get('/levels/$id');
    return res.data as Map<String, dynamic>;
  }
}
```

- [ ] **Step 2: Write the tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write unit tests for `LevelRemoteDataSource` at `test/infrastructure/data_sources/remote/level_remote_data_source_test.dart` in `flutter_arrow_maze`, mirroring the mockito-Dio style of the sibling `test/infrastructure/data_sources/remote/auth_remote_data_source_test.dart`. Use `@GenerateMocks([Dio])` (import `package:mockito/annotations.dart`, `package:mockito/mockito.dart`, `package:dio/dio.dart`) and the generated `level_remote_data_source_test.mocks.dart`. Helper: `Response<dynamic> ok(String path, Object? data) => Response(requestOptions: RequestOptions(path: path), data: data, statusCode: 200);`. AAA, `should_..._when_...`. Under test: `lib/infrastructure/data_sources/remote/level_remote_data_source.dart`. Cover: (1) `fetchLevelIds` does `GET /levels` and returns the raw list — stub `when(dio.get('/levels')).thenAnswer((_) async => ok('/levels', [{'levelId': 'level-01'}, {'levelId': 'level-02'}]))`, assert the returned `List` equals that list, `verify(dio.get('/levels')).called(1)`; (2) `fetchLevel` does `GET /levels/level-01` and returns the raw map — stub `when(dio.get('/levels/level-01')).thenAnswer((_) async => ok('/levels/level-01', {'levelId': 'level-01', 'cols': 4, 'rows': 4, 'arrows': []}))`, assert the map is returned; (3) `fetchLevelIds` propagates `DioException` — `when(dio.get('/levels')).thenThrow(DioException(requestOptions: RequestOptions(path: '/levels'), type: DioExceptionType.connectionError))`, assert `expect(() => dataSource.fetchLevelIds(), throwsA(isA<DioException>()))`; (4) same propagation for `fetchLevel`. Generate mocks with `dart run build_runner build --delete-conflicting-outputs`, then run `flutter test test/infrastructure/data_sources/remote/level_remote_data_source_test.dart`. Return a short summary + paths (including the committed `.mocks.dart`).

- [ ] **Step 3: Verify analyze + tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/infrastructure/data_sources/remote/level_remote_data_source.dart test/infrastructure/data_sources/remote/level_remote_data_source_test.dart` → `No issues found!`
Run: `flutter test test/infrastructure/data_sources/remote/level_remote_data_source_test.dart` → pass.

- [ ] **Step 4: AI_HISTORY + commit**

AI_HISTORY entry title `LevelRemoteDataSource (front#8)`. Then:

```bash
git add lib/infrastructure/data_sources/remote/level_remote_data_source.dart test/infrastructure/data_sources/remote/level_remote_data_source_test.dart test/infrastructure/data_sources/remote/level_remote_data_source_test.mocks.dart AI_HISTORY.MD
git commit -m "feat(infra): add LevelRemoteDataSource"
```

---

### Task 5: `RemoteLevelRepository` + `LevelCacheDataSource`

**Files:**
- Create: `lib/infrastructure/data_sources/local/level_cache_data_source.dart`
- Create: `lib/infrastructure/repositories/remote_level_repository.dart`
- Test: `test/infrastructure/repositories/remote_level_repository_test.dart`

**Interfaces:**
- Consumes: `LevelRemoteDataSource` (Task 4); `LevelJsonDecoder` (Task 3); `ILoggerService` (`lib/core/aspects/i_logger_service.dart`: `log/warn/error`); `Either/Left/Right` (dartz); `DioException` (dio); `Level`, `LevelFailure` (`LevelNotFound`/`LevelUnavailable`/`LevelCorrupted`), `LevelId`, `ILevelRepository`.
- Produces: `class LevelCacheDataSource { static const boxName = 'levels_cache'; List<String>? readCatalog(); Future<void> writeCatalog(List<String>); String? readLevel(String id); Future<void> writeLevel(String id, String rawJson); }`. `class RemoteLevelRepository implements ILevelRepository { RemoteLevelRepository(LevelRemoteDataSource, LevelCacheDataSource, LevelJsonDecoder, ILoggerService); }`.

**Design note (spec §4.4, resolving an implicit corner):** `getLevel` maps `404 → LevelNotFound` (no cache lookup — the back is authority on existence); **any other** `DioException` (network/timeout or a transient server error) falls back to the cache (`Right` if cached, else `LevelUnavailable`); a `FormatException` from the decoder (network **or** cache) → `LevelCorrupted`. `listLevelIds` has no 404 concept: any `DioException` → cache-or-`LevelUnavailable`; corrupt catalog JSON → `LevelCorrupted`. Successful reads are write-through.

- [ ] **Step 1: Create the cache data source**

`lib/infrastructure/data_sources/local/level_cache_data_source.dart`:

```dart
import 'package:hive_ce/hive.dart';

/// Acceso raw a la box Hive `levels_cache` (patrón Petros: DataSource separado
/// del Repository, mockeable en los tests del repo). Persiste el JSON CRUDO de
/// cada nivel (no un modelo tipado): el decoder es la única fuente de verdad del
/// parseo, sin TypeAdapter que mantener. Sin TTL: online siempre refetchea
/// (network-first). La box se abre en el arranque (main); esta clase la obtiene
/// del registro de Hive.
class LevelCacheDataSource {
  static const boxName = 'levels_cache';
  static const _catalogKey = 'catalog';

  Box get _box => Hive.box(boxName);

  /// Ids del Catálogo en orden, o null si nunca se cacheó.
  List<String>? readCatalog() {
    final raw = _box.get(_catalogKey);
    return raw is List ? raw.cast<String>() : null;
  }

  Future<void> writeCatalog(List<String> ids) => _box.put(_catalogKey, ids);

  /// JSON crudo del nivel [id], o null si no está en caché.
  String? readLevel(String id) {
    final raw = _box.get(_levelKey(id));
    return raw is String ? raw : null;
  }

  Future<void> writeLevel(String id, String rawJson) =>
      _box.put(_levelKey(id), rawJson);

  String _levelKey(String id) => 'level:$id';
}
```

- [ ] **Step 2: Create the repository**

`lib/infrastructure/repositories/remote_level_repository.dart`:

```dart
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/entities/level.dart';
import '../../domain/board/failures/level_failure.dart';
import '../../domain/board/repositories/i_level_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../data_sources/local/level_cache_data_source.dart';
import '../data_sources/remote/level_remote_data_source.dart';
import '../serialization/level_json_decoder.dart';

/// Adapter del puerto ILevelRepository. Estrategia network-first con fallback a
/// caché: online siempre refetchea y hace write-through; offline (o error de
/// servidor no-404) sirve la copia cacheada. Aquí muere DioException; ninguna
/// capa superior conoce HTTP. Logging vía ILoggerService (AOP; nunca print).
class RemoteLevelRepository implements ILevelRepository {
  final LevelRemoteDataSource _remote;
  final LevelCacheDataSource _cache;
  final LevelJsonDecoder _decoder;
  final ILoggerService _logger;

  RemoteLevelRepository(this._remote, this._cache, this._decoder, this._logger);

  static const _ctx = 'RemoteLevelRepository';

  @override
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds() async {
    try {
      final raw = await _remote.fetchLevelIds();
      final ids = _parseIds(raw); // FormatException si el JSON es corrupto
      await _cache.writeCatalog([for (final id in ids) id.value]);
      return Right(ids);
    } on DioException {
      // Red/servidor: la copia en caché es el fallback (network-first).
      final cached = _cache.readCatalog();
      if (cached == null) {
        _logger.warn('catalog unavailable offline', _ctx);
        return const Left(LevelUnavailable());
      }
      try {
        return Right([for (final v in cached) LevelId(v)]);
      } catch (err) {
        _logger.error('cached catalog corrupted', _ctx, err);
        return Left(LevelCorrupted('cached catalog: $err'));
      }
    } on FormatException catch (e) {
      _logger.error('catalog corrupted: ${e.message}', _ctx, e);
      return Left(LevelCorrupted(e.message));
    }
  }

  @override
  Future<Either<LevelFailure, Level>> getLevel(LevelId id) async {
    try {
      final raw = await _remote.fetchLevel(id.value);
      final level = _decoder.decode(raw); // FormatException si corrupto
      await _cache.writeLevel(id.value, jsonEncode(raw)); // write-through
      return Right(level);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // El back es autoridad sobre la existencia: no se consulta la caché.
        return Left(LevelNotFound(id));
      }
      return _fromCache(id); // red/servidor no-404 → fallback a caché
    } on FormatException catch (e) {
      _logger.error(
          'level ${id.value} corrupted (network): ${e.message}', _ctx, e);
      return Left(LevelCorrupted(e.message));
    }
  }

  Either<LevelFailure, Level> _fromCache(LevelId id) {
    final raw = _cache.readLevel(id.value);
    if (raw == null) {
      _logger.warn('level ${id.value} unavailable offline', _ctx);
      return const Left(LevelUnavailable());
    }
    try {
      final level =
          _decoder.decode((jsonDecode(raw) as Map).cast<String, Object?>());
      return Right(level);
    } on FormatException catch (e) {
      _logger.error('cached level ${id.value} corrupted: ${e.message}', _ctx, e);
      return Left(LevelCorrupted(e.message));
    }
  }

  List<LevelId> _parseIds(List<dynamic> raw) {
    try {
      return [
        for (final item in raw) LevelId((item as Map)['levelId'] as String),
      ];
    } catch (e) {
      throw FormatException('malformed catalog: $e');
    }
  }
}
```

- [ ] **Step 3: Write the tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write unit tests for `RemoteLevelRepository` at `test/infrastructure/repositories/remote_level_repository_test.dart` in `flutter_arrow_maze`, mirroring the mockito style of `test/infrastructure/repositories/remote_auth_repository_test.dart`. Under test: `lib/infrastructure/repositories/remote_level_repository.dart`, ctor `RemoteLevelRepository(LevelRemoteDataSource remote, LevelCacheDataSource cache, LevelJsonDecoder decoder, ILoggerService logger)`. Use `@GenerateMocks([LevelRemoteDataSource, LevelCacheDataSource, ILoggerService])` and inject a **real** `const LevelJsonDecoder()` (it is pure). Generate mocks with `dart run build_runner build --delete-conflicting-outputs`. AAA, `should_..._when_...`. Provide a `DioException` helper like the auth test's `_dioError({int? status, DioExceptionType type = DioExceptionType.badResponse})`. Use this canonical raw map for a level and its JSON string form:
> ```dart
> final rawLevel = <String, dynamic>{
>   'levelId': 'level-01', 'cols': 4, 'rows': 4,
>   'arrows': [{'id': 'a1', 'headDir': 'right', 'cells': [[0, 0], [0, 1]]}],
> };
> final rawLevelJson = jsonEncode(rawLevel); // dart:convert
> ```
> Stub `MockLevelCacheDataSource.writeLevel`/`writeCatalog` with `thenAnswer((_) async {})` where awaited. Cover **getLevel**: (1) *happy + write-through* — `when(remote.fetchLevel('level-01')).thenAnswer((_) async => rawLevel)`; assert `result` is `Right` and equals `Right(const LevelJsonDecoder().decode(rawLevel))` (Level is Equatable); `verify(cache.writeLevel('level-01', any)).called(1)`; (2) *offline fallback* — `when(remote.fetchLevel('level-01')).thenThrow(_dioError(type: DioExceptionType.connectionError))`, `when(cache.readLevel('level-01')).thenReturn(rawLevelJson)`; assert `Right` with the decoded level; (3) *404* — `when(remote.fetchLevel('level-01')).thenThrow(_dioError(status: 404))`; assert `result == Left(LevelNotFound(LevelId('level-01')))` and `verifyNever(cache.readLevel(any))`; (4) *corrupt from network* — remote returns a map missing `cols`; assert `result.isLeft()` and the left is `LevelCorrupted`; (5) *corrupt from cache* — remote throws network `DioException`, `cache.readLevel` returns `'{ not json'` (or a structurally-invalid map string); assert left is `LevelCorrupted`; (6) *no network, no cache* — remote throws network `DioException`, `cache.readLevel` returns `null`; assert `result == const Left(LevelUnavailable())`. Cover **listLevelIds**: (7) *happy + write-through* — `when(remote.fetchLevelIds()).thenAnswer((_) async => [{'levelId': 'level-01'}, {'levelId': 'level-02'}])`; assert `Right([LevelId('level-01'), LevelId('level-02')])`; `verify(cache.writeCatalog(['level-01', 'level-02'])).called(1)`; (8) *offline fallback* — remote throws network `DioException`, `cache.readCatalog` returns `['level-01', 'level-02']`; assert `Right` with those ids; (9) *offline, no cache* — remote throws, `cache.readCatalog` returns `null`; assert `const Left(LevelUnavailable())`; (10) *corrupt catalog* — remote returns `[{'nope': 1}]`; assert left is `LevelCorrupted`. Assert equality of `Left`/`Right` using dartz (e.g. `expect(result, Left<LevelFailure, Level>(LevelNotFound(LevelId('level-01'))))` — LevelFailure is Equatable). Run `flutter test test/infrastructure/repositories/remote_level_repository_test.dart`. Note: `LevelCacheDataSource` is a thin Hive wrapper and, per the project's convention (local data sources are not unit-tested directly, only mocked at the repo boundary — see `data_sources/local/` has no tests), gets no standalone test. Return a short summary + paths (including `.mocks.dart`).

- [ ] **Step 4: Verify analyze + tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/infrastructure/data_sources/local/level_cache_data_source.dart lib/infrastructure/repositories/remote_level_repository.dart test/infrastructure/repositories/remote_level_repository_test.dart` → `No issues found!`
Run: `flutter test test/infrastructure/repositories/remote_level_repository_test.dart` → pass.

- [ ] **Step 5: AI_HISTORY + commit**

AI_HISTORY entry title `RemoteLevelRepository + LevelCacheDataSource (front#8)`. Then:

```bash
git add lib/infrastructure/data_sources/local/level_cache_data_source.dart lib/infrastructure/repositories/remote_level_repository.dart test/infrastructure/repositories/remote_level_repository_test.dart test/infrastructure/repositories/remote_level_repository_test.mocks.dart AI_HISTORY.MD
git commit -m "feat(infra): add RemoteLevelRepository with network-first cache"
```

---

### Task 6: `levelCatalogProvider` (application) with background prefetch

**Files:**
- Create: `lib/application/providers/level_catalog_provider.dart`
- Test: `test/application/providers/level_catalog_provider_test.dart`

**Interfaces:**
- Consumes: `ILevelRepository` (Task 2/5); `ILoggerService`; `LevelId`; `AsyncNotifier`/`AsyncNotifierProvider` (flutter_riverpod).
- Produces: `final levelCatalogProvider = AsyncNotifierProvider<LevelCatalogNotifier, List<LevelId>>(...)` (throw-default factory, overridden in `main`). `class LevelCatalogNotifier extends AsyncNotifier<List<LevelId>> { LevelCatalogNotifier(ILevelRepository, ILoggerService); void refresh(); }`.

- [ ] **Step 1: Create the provider + notifier**

`lib/application/providers/level_catalog_provider.dart`:

```dart
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
```

- [ ] **Step 2: Write the tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write unit tests for `levelCatalogProvider` / `LevelCatalogNotifier` at `test/application/providers/level_catalog_provider_test.dart` in `flutter_arrow_maze`, using `ProviderContainer` overrides (see `test/application/state/game_controller_test.dart` for the container+mock idiom). Under test: `lib/application/providers/level_catalog_provider.dart`. Use `@GenerateMocks([ILevelRepository, ILoggerService])` (import the port `domain/board/repositories/i_level_repository.dart` and `core/aspects/i_logger_service.dart`); generate with `dart run build_runner build --delete-conflicting-outputs`. Build a container helper:
> ```dart
> ProviderContainer _container(MockILevelRepository repo, MockILoggerService logger) {
>   final c = ProviderContainer(overrides: [
>     levelCatalogProvider.overrideWith(() => LevelCatalogNotifier(repo, logger)),
>   ]);
>   addTearDown(c.dispose);
>   return c;
> }
> ```
> Use `final ids = [LevelId('level-01'), LevelId('level-02')];` and a helper `Level` (import `domain/board/entities/level.dart`; build a minimal `Level(id: LevelId('level-01'), board: ArrowBoard(arrows: [Arrow(id: ArrowId('a'), cells: [Position(row:0,col:0), Position(row:0,col:1)], headDirection: Direction.right)], cols: 4, rows: 4))`). AAA, `should_..._when_...`. Cover: (1) *catalog ok* — `when(repo.listLevelIds()).thenAnswer((_) async => Right(ids))`, `when(repo.getLevel(any)).thenAnswer((_) async => Right(level))`; `final result = await c.read(levelCatalogProvider.future);` assert `result == ids`; then `await pumpEventQueue();` and `verify(repo.getLevel(LevelId('level-01'))).called(1); verify(repo.getLevel(LevelId('level-02'))).called(1);` (prefetch ran for every id); (2) *error* — `when(repo.listLevelIds()).thenAnswer((_) async => Left(LevelUnavailable()))` (import `domain/board/failures/level_failure.dart`); assert `expect(() => c.read(levelCatalogProvider.future), throwsA(isA<LevelUnavailable>()))` and that `c.read(levelCatalogProvider)` is `AsyncError` whose error `isA<LevelUnavailable>()`; (3) *prefetch resilience* — `listLevelIds` returns `Right(ids)`, `when(repo.getLevel(LevelId('level-01'))).thenAnswer((_) async => Left(const LevelUnavailable()))`, `when(repo.getLevel(LevelId('level-02'))).thenAnswer((_) async => Right(level))`; assert `await c.read(levelCatalogProvider.future) == ids` (a failing prefetch does NOT break the load) and, after `pumpEventQueue()`, `verify(logger.warn(any, any)).called(1)`; (4) *refresh* — first call `listLevelIds` returns `Left(LevelUnavailable())` (state becomes error), then restub to `Right(ids)` and `getLevel` to `Right(level)`, call `c.read(levelCatalogProvider.notifier).refresh()`, `await pumpEventQueue()` / `await c.read(levelCatalogProvider.future)`, assert the value is now `ids`. Import dartz `Left`/`Right`. Run `flutter test test/application/providers/level_catalog_provider_test.dart`. Return a short summary + paths (including `.mocks.dart`).

- [ ] **Step 3: Verify analyze + tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze lib/application/providers/level_catalog_provider.dart test/application/providers/level_catalog_provider_test.dart` → `No issues found!`
Run: `flutter test test/application/providers/level_catalog_provider_test.dart` → pass.

- [ ] **Step 4: AI_HISTORY + commit**

AI_HISTORY entry title `levelCatalogProvider + background prefetch (front#8)`. Then:

```bash
git add lib/application/providers/level_catalog_provider.dart test/application/providers/level_catalog_provider_test.dart test/application/providers/level_catalog_provider_test.mocks.dart AI_HISTORY.MD
git commit -m "feat(app): add levelCatalogProvider with background prefetch"
```

---

### Task 7: Rewire `GameController` to load remotely + compose DI in `main`

This fragment is atomic: the `GameController` constructor changes (generator → repository), which ripples to `main.dart`. Both, plus the DI seam and the controller-test rewrite, land together so the project compiles and its suites stay green.

**Files:**
- Modify: `lib/application/state/game_controller.dart`
- Modify: `lib/presentation/providers/dependency_providers.dart`
- Modify: `lib/main.dart`
- Test: rewrite `test/application/state/game_controller_test.dart` (+ regenerate `test/application/state/game_controller_test.mocks.dart`)

**Interfaces:**
- Consumes: `ILevelRepository` (Task 2); `Level` (Task 1); `RemoteLevelRepository`, `LevelRemoteDataSource`, `LevelCacheDataSource`, `LevelJsonDecoder` (Tasks 3–5); `levelCatalogProvider`/`LevelCatalogNotifier` (Task 6).
- Produces: `GameController(ILevelRepository levelRepository, RemoveArrowUseCase, CommandInvoker, [ITicker])`; `loadLevel` is now `Future<void>` async-remote (sets `AsyncValue.loading()` → `AsyncValue.data(GamePlaying)` or `AsyncValue.error(LevelFailure)`); `restartLevel` reuses the cached `Level` without refetch. `final levelRepositoryProvider = Provider<ILevelRepository>(...)` (throw-default, overridden in `main`).

- [ ] **Step 1: Rewrite `game_controller.dart` imports + fields + constructor**

In `lib/application/state/game_controller.dart`: **remove** the imports
`import '../../domain/arrows/services/i_level_generator.dart';` and
`import '../../domain/board/value_objects/level_blueprint.dart';`, and **add**
`import '../../domain/board/entities/level.dart';` and
`import '../../domain/board/repositories/i_level_repository.dart';`
(keep `arrow_board.dart`, `arrow_id.dart`, `level_id.dart`, and the rest).

Replace the field + constructor:

```dart
  final ILevelRepository _levelRepository;
  final RemoveArrowUseCase _removeArrow;
  final CommandInvoker _invoker;
  final ITicker _ticker;

  GameController(this._levelRepository, this._removeArrow, this._invoker,
      [this._ticker = const NullTicker()]);
```

Add a field next to `LevelId? _currentLevel;`:

```dart
  // Datos del nivel remoto en curso (spec §5.2). Restart lo reutiliza sin
  // refetch; undo-tras-victoria toma de aquí las dimensiones reales del tablero.
  Level? _currentLevelData;
```

- [ ] **Step 2: Replace `loadLevel` and `restartLevel`, add `_startLevel`**

Replace the whole `loadLevel(...)` method with:

```dart
  Future<void> loadLevel(LevelId levelId) async {
    // Aseguramos que build() haya resuelto antes de mutar el estado.
    await future;
    _cancelTimer();
    _cancelElapsed();
    state = const AsyncValue<GameState>.loading();
    final result = await _levelRepository.getLevel(levelId);
    result.fold(
      (failure) {
        // Reutilizamos el AsyncValue que ya envuelve GameState; sin caso nuevo
        // en el sealed. La UI discrimina el LevelFailure en la rama de error.
        state = AsyncValue.error(failure, StackTrace.current);
      },
      (level) {
        _currentLevel = levelId;
        _currentLevelData = level;
        _startLevel(level);
      },
    );
  }

  // Monta el nivel [level] en el estado de partida. Reutilizado por loadLevel
  // (tras el fetch) y por restartLevel (sin refetch). Arranca el cronómetro y,
  // si el nivel es cronometrado, la cuenta atrás.
  void _startLevel(Level level) {
    _cancelTimer();
    _cancelElapsed();
    _blockedNonce = 0;
    _exitNonce = 0;
    _strikes = const StrikeCount(0);
    _invoker.clear();
    _remainingSeconds = level.timeLimitSec;
    _optimalMoves = level.board.arrows.length; // óptimo = nº de flechas
    _startElapsed();
    state = AsyncValue.data(GamePlaying(
      board: level.board,
      moves: const MoveCount(0),
      canUndo: false,
      remainingSeconds: _remainingSeconds,
    ));
    final limit = level.timeLimitSec;
    if (limit != null) _startTimer(limit);
  }
```

Replace `restartLevel()` with:

```dart
  Future<void> restartLevel() async {
    final level = _currentLevelData;
    if (level != null) _startLevel(level); // sin refetch: mismo Level cacheado
  }
```

- [ ] **Step 3: Fix the `undoMove` post-victory branch**

In `undoMove()`, replace the `else if (current is GameWon)` branch (which used `LevelBlueprint.forLevel(...)`) with:

```dart
    } else if (current is GameWon) {
      // Tras la victoria el tablero quedó vacío; reconstruimos uno vacío con las
      // dimensiones REALES del nivel remoto para reinsertar bien.
      final data = _currentLevelData;
      if (data == null) return;
      currentBoard =
          ArrowBoard(arrows: const [], cols: data.board.cols, rows: data.board.rows);
      currentMoves = current.moves.value;
    } else {
      return;
    }
```

This removes the last `LevelBlueprint`/`ILevelGenerator` reference in the controller.

- [ ] **Step 4: Add the `levelRepositoryProvider` seam in `dependency_providers.dart`**

In `lib/presentation/providers/dependency_providers.dart` add the import
`import '../../domain/board/repositories/i_level_repository.dart';` and, near the other repository providers, add:

```dart
// front#8: repo remoto de niveles compuesto en main con el Dio firmado + la box
// levels_cache abierta al arranque (DIP). Las capas internas solo conocen el
// puerto ILevelRepository. Igual patrón que remoteProgressRepositoryProvider.
final levelRepositoryProvider = Provider<ILevelRepository>(
  (_) => throw UnimplementedError(
    'levelRepositoryProvider must be overridden in main with composed Dio + levels_cache box',
  ),
);
```

Leave `levelGeneratorProvider` untouched (front#36 base).

- [ ] **Step 5: Compose in `main.dart`**

In `lib/main.dart`:

1. **Add** imports:
   ```dart
   import 'application/providers/level_catalog_provider.dart';
   import 'infrastructure/data_sources/local/level_cache_data_source.dart';
   import 'infrastructure/data_sources/remote/level_remote_data_source.dart';
   import 'infrastructure/repositories/remote_level_repository.dart';
   import 'infrastructure/serialization/level_json_decoder.dart';
   ```
2. **Remove** the now-unused import `import 'infrastructure/generators/graph_board_generator.dart';` (it was only used to build the game override).
3. **Open the cache box** — after `await Hive.openBox<LevelProgressHiveModel>('level_progress');` add:
   ```dart
   // front#8: box sin tipar para el JSON crudo de los niveles remotos (catálogo
   // + un entry por nivel). Sin TTL: online siempre refetchea (network-first).
   await Hive.openBox(LevelCacheDataSource.boxName);
   ```
4. **Compose the repository** — after `final dio = DioClient.create(sessionTokenStore);` (and the `authRepository` line) add:
   ```dart
   // front#8: repo remoto de niveles (network-first + caché) con el mismo Dio
   // firmado y la box levels_cache abierta arriba. Alimenta el Catálogo y la
   // carga de partida; DioException muere dentro del repo.
   final levelRepository = RemoteLevelRepository(
     LevelRemoteDataSource(dio),
     LevelCacheDataSource(),
     const LevelJsonDecoder(),
     LoggerServiceAdapter(),
   );
   ```
5. **Update the `gameControllerProvider` override** to pass the repository instead of `GraphBoardGenerator()` (adjust the preceding comment accordingly):
   ```dart
   // GameController compuesto con sus dependencias concretas (DIP). Ahora carga
   // los niveles oficiales vía ILevelRepository (front#8) en lugar de generarlos;
   // incluye el reloj real (SystemTicker) para los niveles con límite (front#11).
   gameControllerProvider.overrideWith(
     () => GameController(
       levelRepository,
       RemoveArrowUseCase(),
       CommandInvoker(),
       const SystemTicker(),
     ),
   ),
   ```
6. **Add** two overrides in the same `overrides:` list:
   ```dart
   // front#8: el puerto de niveles y el Catálogo comparten la misma instancia
   // del repo remoto compuesta arriba.
   levelRepositoryProvider.overrideWithValue(levelRepository),
   levelCatalogProvider.overrideWith(
     () => LevelCatalogNotifier(levelRepository, LoggerServiceAdapter()),
   ),
   ```

- [ ] **Step 6: Rewrite the controller test (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Rewrite `test/application/state/game_controller_test.dart` in `flutter_arrow_maze` because `GameController`'s first dependency changed from `ILevelGenerator` to `ILevelRepository` (ctor is now `GameController(ILevelRepository levelRepository, RemoveArrowUseCase removeArrow, CommandInvoker invoker, [ITicker ticker])`; `loadLevel` is async-remote). Keep AAA and the existing `should_..._when_...` names. Changes:
> - `@GenerateMocks([ILevelRepository, RemoveArrowUseCase])` (drop `ILevelGenerator`; import `package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart`, `.../domain/board/entities/level.dart`, dartz `Left`/`Right`, `.../domain/board/failures/level_failure.dart`). Regenerate with `dart run build_runner build --delete-conflicting-outputs`.
> - Replace `_stubGenerate` with a stub that returns a `Level`: `void _stubLevel(MockILevelRepository repo, ArrowBoard board, {int? timeLimitSec}) => when(repo.getLevel(any)).thenAnswer((_) async => Right(Level(id: LevelId('1'), board: board, timeLimitSec: timeLimitSec)));`. Keep `_twoArrowBoard()`/`_oneArrowBoard()`/`_arrow(...)` helpers as-is.
> - Update `_container`/`_containerWithTicker` to build `GameController(repo, uc, CommandInvoker())` / `GameController(repo, uc, CommandInvoker(), ticker)` with a `MockILevelRepository repo`.
> - **Timer tests**: the countdown now comes from `Level.timeLimitSec`, not `LevelBlueprint`. Drop the `import '.../level_blueprint.dart';` and the `timedLevel`/`timedLimit` locals derived from it. For timed cases, stub with a concrete limit: `_stubLevel(repo, _twoArrowBoard(), timeLimitSec: 60)` and assert `ticker.requestedSeconds == 60` / `remainingSeconds == 60`. For the no-limit case stub with `timeLimitSec: null` and assert `ticker.requestedSeconds` is null.
> - Adapt every existing behavioral test (loadLevel → GamePlaying; tapArrow blocked/legal; GameWon score/stars/time/level; strikes 4th/5th; undo; undo-after-victory move count; restart resets; countdown update; lose-on-timeout; ignore-timeout-after-win) to this stubbing — behavior and assertions are unchanged; only the board now arrives via `getLevel` instead of `generate`.
> - **Add new tests** for the remote path: (a) `should_emit_error_when_getLevel_fails` — `when(repo.getLevel(any)).thenAnswer((_) async => Left(const LevelUnavailable()))`, call `loadLevel(LevelId('1'))`, assert `c.read(gameControllerProvider)` is `AsyncError` whose error `isA<LevelUnavailable>()` (and `valueOrNull` is null); (b) `should_not_refetch_when_restart` — `_stubLevel(...)`, `await loadLevel(LevelId('1'))`, `await restartLevel()`, then `verify(repo.getLevel(any)).called(1)` (restart reused the cached Level) and state is `GamePlaying` with 0 moves; (c) `should_use_remote_time_limit_when_present` (covered by the timed stub above); (d) `should_set_optimal_moves_from_board` — implicitly verified by an existing perfect-run GameWon test (optimal = arrows length), keep it. Run `flutter test test/application/state/game_controller_test.dart`. Return a short summary + confirmation the whole file compiles and passes.

- [ ] **Step 7: Verify analyze + tests (whole app compiles)**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter analyze` (whole project) — Expected: `No issues found!` (this is the first fragment where `main.dart` references the new wiring; the app must compile end-to-end).
Run: `flutter test test/application/state/game_controller_test.dart` → pass.

- [ ] **Step 8: AI_HISTORY + commit**

AI_HISTORY entry title `GameController remote loadLevel + DI composition (front#8)`. Then:

```bash
git add lib/application/state/game_controller.dart lib/presentation/providers/dependency_providers.dart lib/main.dart test/application/state/game_controller_test.dart test/application/state/game_controller_test.mocks.dart AI_HISTORY.MD
git commit -m "refactor(app): load campaign levels from ILevelRepository"
```

---

### Task 8: `LevelSelectionScreen` driven by the Catálogo

**Files:**
- Modify: `lib/presentation/level_selection/level_selection_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` (add `catalogError`)
- Test: `test/presentation/level_selection/level_selection_screen_test.dart` (create or extend)

**Interfaces:**
- Consumes: `levelCatalogProvider` (Task 6, `AsyncValue<List<LevelId>>` + `.notifier.refresh()`); `AppLocalizations` keys `selectLevel`, `catalogError`, `retry`; `AppRouter.game`; `LevelId` (route arg).
- Produces: a `ConsumerWidget` grid whose cell `i` shows `'${i + 1}'` (Catálogo position) but navigates with the real `ids[i]`.

- [ ] **Step 1: Add the l10n key**

In `lib/l10n/app_en.arb` add (before the closing brace, keeping valid JSON):

```json
  "catalogError": "Couldn't load levels",
  "@catalogError": {
    "description": "Shown on the level selection screen when the catalog fails to load."
  },
```

In `lib/l10n/app_es.arb` add:

```json
  "catalogError": "No se pudieron cargar los niveles",
```

Run: `flutter gen-l10n`.

- [ ] **Step 2: Rewrite the screen**

Replace the whole content of `lib/presentation/level_selection/level_selection_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/level_catalog_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Cuadrícula de selección de nivel alimentada por el Catálogo remoto
/// (levelCatalogProvider). Cada celda muestra su POSICIÓN en el Catálogo
/// (`i + 1`) pero navega con el LevelId REAL del back, alineando juego y
/// leaderboard con los ids oficiales. loading → spinner; error → mensaje +
/// reintentar (refresh del Catálogo).
class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final catalog = ref.watch(levelCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLevel),
        backgroundColor: surface,
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _CatalogError(
          message: l10n.catalogError,
          retryLabel: l10n.retry,
          onRetry: () => ref.read(levelCatalogProvider.notifier).refresh(),
        ),
        data: (ids) => _LevelGrid(ids: ids),
      ),
    );
  }
}

/// Cuadrícula de niveles: `ids.length` celdas, cada una etiquetada por su
/// posición (i+1) y con navegación al LevelId real correspondiente.
class _LevelGrid extends StatelessWidget {
  final List<LevelId> ids;
  const _LevelGrid({required this.ids});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassFill = isDark ? AppColors.glassFill : AppColors.lightGlassFill;
    final glassBorder =
        isDark ? AppColors.glassBorder : AppColors.lightGlassBorder;
    final onBackground =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: ids.length,
      itemBuilder: (context, i) => InkWell(
        // La celda muestra la posición (i+1) pero navega con el LevelId real.
        onTap: () =>
            Navigator.pushNamed(context, AppRouter.game, arguments: ids[i]),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glassBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            '${i + 1}',
            style: TextStyle(
              color: onBackground,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado de error del Catálogo: mensaje + botón de reintentar.
class _CatalogError extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _CatalogError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write the widget tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write widget tests for `LevelSelectionScreen` at `test/presentation/level_selection/level_selection_screen_test.dart` in `flutter_arrow_maze` (match the conventions of existing tests under `test/presentation/`). The screen is now a `ConsumerWidget` reading `levelCatalogProvider`. Pump it inside a `ProviderScope(overrides: [...])` wrapping a `MaterialApp` with `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: const [Locale('es'), Locale('en')]`, `locale: const Locale('en')`, `onGenerateRoute: (s) => ...` or `routes:` so navigation can be asserted, and `home: const LevelSelectionScreen()`. To drive the three states, override `levelCatalogProvider` with a tiny fake notifier per test:
> ```dart
> class _FakeCatalog extends LevelCatalogNotifier {
>   final FutureOr<List<LevelId>> Function() _build;
>   _FakeCatalog(this._build) : super(_ThrowingRepo(), _NoopLogger());
>   @override
>   Future<List<LevelId>> build() async => _build();
> }
> ```
> (or simpler: override with `AsyncNotifierProvider` fakes returning loading/data/error — use whatever cleanly forces each `AsyncValue`; a mockito `MockILevelRepository` + real `LevelCatalogNotifier` also works: stub `listLevelIds` to `Right(ids)` / `Left(LevelUnavailable())` and `getLevel` to `Right(level)`). AAA, `should_..._when_...`. Cover: (1) *loading* → a `CircularProgressIndicator` is shown; (2) *error* → the `catalogError` text ("Couldn't load levels") and a retry button (`FilledButton` with the `retry` label "Retry") are shown; tapping retry calls `refresh()` (assert via a spy/mock or by re-stubbing to data and pumping so the grid appears); (3) *data with 3 ids* (`[LevelId('level-01'), LevelId('level-02'), LevelId('level-03')]`) → exactly 3 cells labeled `'1'`,`'2'`,`'3'` (`find.text('1')`, etc.); (4) *navigation* → tapping the first cell pushes `AppRouter.game` with `LevelId('level-01')` as the argument (assert with a mock `NavigatorObserver` or by capturing route settings). Run `flutter test test/presentation/level_selection/level_selection_screen_test.dart`. If mocks are needed, generate them with build_runner and commit the `.mocks.dart`. Return a short summary + paths.

- [ ] **Step 4: Verify analyze + tests**

Run: `flutter gen-l10n` (if not already) → then `flutter analyze lib/presentation/level_selection/level_selection_screen.dart test/presentation/level_selection/level_selection_screen_test.dart` → `No issues found!`
Run: `flutter test test/presentation/level_selection/level_selection_screen_test.dart` → pass.

- [ ] **Step 5: AI_HISTORY + commit**

AI_HISTORY entry title `LevelSelectionScreen from Catálogo (front#8)`. Then (include any `.mocks.dart` produced):

```bash
git add lib/presentation/level_selection/level_selection_screen.dart lib/l10n/app_en.arb lib/l10n/app_es.arb test/presentation/level_selection/level_selection_screen_test.dart AI_HISTORY.MD
git commit -m "feat(front): drive level selection from remote catalog"
```

---

### Task 9: `VictoryScreen` "next level" from the Catálogo

**Files:**
- Modify: `lib/presentation/level_selection/victory_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` (add `campaignComplete`)
- Test: `test/presentation/level_selection/victory_screen_test.dart` (create or extend)

**Interfaces:**
- Consumes: `levelCatalogProvider` (`.valueOrNull` → `List<LevelId>`); `VictoryArgs` (unchanged `typedef`); `AppLocalizations` keys `victoryTitle`, `victoryScore`, `victoryMoves`, `nextLevel`, `backToLevels`, `campaignComplete`; `AppRouter.game`/`levelSelection`.
- Produces: a `ConsumerWidget` that computes `next = ids[indexOf(current) + 1]`, shows "Next Level" when a next exists, and the campaign-complete copy on the last level.

- [ ] **Step 1: Add the l10n key**

`lib/l10n/app_en.arb`:

```json
  "campaignComplete": "You've completed all levels!",
  "@campaignComplete": {
    "description": "Shown on the victory screen after clearing the last level in the catalog."
  },
```

`lib/l10n/app_es.arb`:

```json
  "campaignComplete": "¡Has completado todos los niveles!",
```

Run: `flutter gen-l10n`.

- [ ] **Step 2: Rewrite the screen**

Replace the whole content of `lib/presentation/level_selection/victory_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/level_catalog_provider.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../l10n/app_localizations.dart';

/// Argumentos de la ruta de victoria. Transporta el [levelId] (para calcular el
/// siguiente del Catálogo) y las métricas ya evaluadas por el `GameController`
/// (front#16): [moves], [score] y [stars] (1–3). La pantalla no calcula nada.
typedef VictoryArgs = ({LevelId levelId, int moves, int score, int stars});

/// Pantalla de victoria. El "siguiente nivel" lo dicta el Catálogo
/// (levelCatalogProvider): next = ids[indexOf(actual) + 1]. En el último nivel se
/// oculta el CTA y aparece la felicitación de campaña completada. Sin pantalla
/// nueva. Vista pasiva: recibe [VictoryArgs] via `ModalRoute`.
class VictoryScreen extends ConsumerWidget {
  const VictoryScreen({super.key});

  static const int _maxStars = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as VictoryArgs?;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.lightPrimary;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    final starCount = args?.stars ?? 0;
    final score = args?.score ?? 0;
    final moves = args?.moves ?? 0;

    // Orden de juego del Catálogo; el siguiente nivel es el posterior en la lista.
    final ids = ref.watch(levelCatalogProvider).valueOrNull ?? const <LevelId>[];
    final index = args == null ? -1 : ids.indexOf(args.levelId);
    final nextId = (index >= 0 && index + 1 < ids.length) ? ids[index + 1] : null;
    final isLastLevel = index >= 0 && index == ids.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.victoryTitle,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: AppColors.success),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _maxStars,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.star,
                      size: 56,
                      color: i < starCount ? AppColors.success : muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.victoryScore(score),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark
                      ? AppColors.onBackground
                      : AppColors.lightOnBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.victoryMoves(moves),
                style: theme.textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const SizedBox(height: 48),
              // Siguiente nivel dictado por el Catálogo; en el último, felicitación.
              if (nextId != null)
                FilledButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    AppRouter.game,
                    arguments: nextId,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor:
                        isDark ? AppColors.background : AppColors.lightSurface,
                  ),
                  child: Text(l10n.nextLevel),
                )
              else if (isLastLevel)
                Text(
                  l10n.campaignComplete,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: AppColors.success),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRouter.levelSelection,
                  (_) => false,
                ),
                child: Text(l10n.backToLevels, style: TextStyle(color: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write the widget tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write widget tests for `VictoryScreen` at `test/presentation/level_selection/victory_screen_test.dart` in `flutter_arrow_maze` (match `test/presentation/` conventions). The screen is now a `ConsumerWidget` reading `levelCatalogProvider` and receiving `VictoryArgs` via the route. Pump inside `ProviderScope(overrides: [levelCatalogProvider override that resolves to a fixed `List<LevelId>`])` + `MaterialApp` with the l10n delegates, `locale: const Locale('en')`, and a route that supplies `VictoryScreen` with `settings.arguments` = a `VictoryArgs`. Easiest catalog override: `levelCatalogProvider.overrideWith(() => _StubCatalog(ids))` where `_StubCatalog extends LevelCatalogNotifier` with `@override Future<List<LevelId>> build() async => ids;` (construct super with mockito mocks that are never called), OR override with a `MockILevelRepository` whose `listLevelIds` returns `Right(ids)` and `getLevel` returns `Right(level)`. Use `ids = [LevelId('level-01'), LevelId('level-02'), LevelId('level-03')]`. AAA, `should_..._when_...`. Cover: (1) *middle level* — args `levelId: LevelId('level-01')`; the `nextLevel` button ("Next Level") is present and the `campaignComplete` text is absent; tapping it does `pushReplacementNamed(AppRouter.game, arguments: LevelId('level-02'))` (assert with a `NavigatorObserver` mock or captured settings); (2) *last level* — args `levelId: LevelId('level-03')`; the `nextLevel` button is absent (`find.text('Next Level')` → `findsNothing`) and the `campaignComplete` text ("You've completed all levels!") is shown; (3) *back button* — the `backToLevels` button ("Back to Levels") is always present and pushes `AppRouter.levelSelection`; (4) *score/moves/stars* rendering from args is unchanged (assert `victoryScore`/`victoryMoves` texts and that `starCount` filled stars render). Run `flutter test test/presentation/level_selection/victory_screen_test.dart`. Commit any `.mocks.dart`. Return a short summary + paths.

- [ ] **Step 4: Verify analyze + tests**

Run: `flutter gen-l10n` → `flutter analyze lib/presentation/level_selection/victory_screen.dart test/presentation/level_selection/victory_screen_test.dart` → `No issues found!`
Run: `flutter test test/presentation/level_selection/victory_screen_test.dart` → pass.

- [ ] **Step 5: AI_HISTORY + commit**

AI_HISTORY entry title `VictoryScreen next-from-Catálogo + campaña completada (front#8)`. Then:

```bash
git add lib/presentation/level_selection/victory_screen.dart lib/l10n/app_en.arb lib/l10n/app_es.arb test/presentation/level_selection/victory_screen_test.dart AI_HISTORY.MD
git commit -m "feat(front): pick next level from catalog on victory"
```

---

### Task 10: `GameScreen` error branch discriminates `LevelFailure`

**Files:**
- Modify: `lib/presentation/game/screens/game_screen.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` (add `levelUnavailable`, `levelLoadError`)
- Test: `test/presentation/game/screens/game_screen_test.dart` (create or extend)

**Interfaces:**
- Consumes: the game `AsyncValue<GameState>` error object is now a `LevelFailure` (Task 7); `LevelUnavailable`/`LevelNotFound`/`LevelCorrupted` (`lib/domain/board/failures/level_failure.dart`); `AppLocalizations` keys `levelUnavailable`, `levelLoadError`, `retry`, `backToLevels`; `AppRouter.levelSelection`; `gameControllerProvider.notifier.loadLevel`.
- Produces: an error branch that offers retry on `LevelUnavailable` and a terminal "back to levels" on `LevelNotFound`/`LevelCorrupted`.

- [ ] **Step 1: Add the l10n keys**

`lib/l10n/app_en.arb`:

```json
  "levelUnavailable": "This level isn't available offline",
  "@levelUnavailable": {
    "description": "Game screen: shown when the level can't be fetched and isn't cached."
  },
  "levelLoadError": "This level couldn't be loaded",
  "@levelLoadError": {
    "description": "Game screen: terminal error for a missing or corrupted level."
  },
```

`lib/l10n/app_es.arb`:

```json
  "levelUnavailable": "Este nivel no está disponible sin conexión",
  "levelLoadError": "No se pudo cargar este nivel",
```

Run: `flutter gen-l10n`.

- [ ] **Step 2: Add the `LevelFailure` import**

In `lib/presentation/game/screens/game_screen.dart`, add with the other domain imports:

```dart
import '../../../domain/board/failures/level_failure.dart';
```

- [ ] **Step 3: Replace the body's error branch**

In `build`, replace the `body:`'s `asyncState.when(...)` error line:

```dart
      body: Center(
        child: asyncState.when(
          data: (_) => const BoardWidget(),
          loading: () => CircularProgressIndicator(color: primary),
          error: (e, _) => _GameError(
            failure: e,
            onRetry: () =>
                ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId),
          ),
        ),
      ),
```

(The AppBar's `error: (e, _) => Text(l10n.error)` title branch stays as-is.)

- [ ] **Step 4: Add the `_GameError` widget**

Append to `lib/presentation/game/screens/game_screen.dart` (after `_CountdownChip`):

```dart
/// Rama de error de la carga remota del nivel. Discrimina el LevelFailure:
/// LevelUnavailable (sin conexión) ofrece reintentar; el resto (no encontrado /
/// corrupto) es terminal y vuelve al selector. Recibe el fallo como `Object`
/// (lo que entrega `AsyncError`) y hace el type-check aquí.
class _GameError extends StatelessWidget {
  final Object failure;
  final VoidCallback onRetry;
  const _GameError({required this.failure, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (failure is LevelUnavailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.levelUnavailable, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      );
    }
    // LevelNotFound / LevelCorrupted (o cualquier otro error): terminal.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.levelLoadError, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRouter.levelSelection,
            (_) => false,
          ),
          child: Text(l10n.backToLevels),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write the widget tests (dispatch `qa` subagent)**

Dispatch a subagent with the **arrowmaze-qa** skill and the following prompt:

> Write/extend widget tests for `GameScreen`'s error branch at `test/presentation/game/screens/game_screen_test.dart` in `flutter_arrow_maze` (match `test/presentation/` conventions; a `game_screen_test.dart` may already exist — extend it, don't duplicate its setup). `GameScreen` is a `ConsumerStatefulWidget` that on first frame calls `gameControllerProvider.notifier.loadLevel(widget.levelId)`. To force the error `AsyncValue`, override `gameControllerProvider` with a `GameController` built from a `MockILevelRepository` whose `getLevel` returns the desired `Left(LevelFailure)`, and override `audioServiceProvider` with `const SilentAudioService()` and `scoreSubmissionObserverProvider` as needed (see how existing game_screen/game tests compose the container). Pump inside `ProviderScope(overrides: [...])` + `MaterialApp` with l10n delegates, `locale: const Locale('en')`, an `onGenerateRoute` that can build `AppRouter.levelSelection`, and `home: const GameScreen(levelId: LevelId('level-01'))`. Let the post-frame `loadLevel` run (`await tester.pumpAndSettle()`), which resolves to `AsyncError`. AAA, `should_..._when_...`. Cover: (1) *LevelUnavailable* — `getLevel` → `Left(const LevelUnavailable())`; assert the `levelUnavailable` text ("This level isn't available offline") and a retry `FilledButton` (label "Retry") are shown; tapping retry calls `loadLevel` again (re-stub `getLevel` to `Right(level)` and assert the board appears, or verify the notifier call via a spy); (2) *LevelNotFound* — `getLevel` → `Left(LevelNotFound(LevelId('level-01')))`; assert the `levelLoadError` text ("This level couldn't be loaded") and a "Back to Levels" `TextButton` are shown, and no retry button; tapping it navigates to `AppRouter.levelSelection`; (3) *LevelCorrupted* — `getLevel` → `Left(LevelCorrupted('bad'))`; assert the same terminal `levelLoadError` + back button (no retry). Build the `Right(level)` `Level` minimally as in the other tasks. Run `flutter test test/presentation/game/screens/game_screen_test.dart`. Commit any `.mocks.dart`. Return a short summary + paths.

- [ ] **Step 6: Verify analyze + tests**

Run: `flutter gen-l10n` → `flutter analyze lib/presentation/game/screens/game_screen.dart test/presentation/game/screens/game_screen_test.dart` → `No issues found!`
Run: `flutter test test/presentation/game/screens/game_screen_test.dart` → pass.

- [ ] **Step 7: AI_HISTORY + commit**

AI_HISTORY entry title `GameScreen LevelFailure error branch (front#8)`. Then:

```bash
git add lib/presentation/game/screens/game_screen.dart lib/l10n/app_en.arb lib/l10n/app_es.arb test/presentation/game/screens/game_screen_test.dart AI_HISTORY.MD
git commit -m "feat(front): discriminate LevelFailure in game error branch"
```

---

### Task 11: Housekeeping — README, issue comment, final DoD

**Files:**
- Modify: `MazePruebaFront/README.md`
- (No code; final verification of the whole artefact.)

- [ ] **Step 1: Update the README**

Update `MazePruebaFront/README.md` to reflect that the campaign is now **remote**:
- In the architecture/usage section, state that campaign levels come from `MazePruebaBack` (`GET /levels`, `GET /levels/:id`) via `ILevelRepository` → `RemoteLevelRepository` (network-first with a Hive `levels_cache` fallback), that "next level" follows the back's **Catálogo** order, and that the app requires `AppConfig.apiBaseUrl` to reach the API. Note offline behavior (cached campaign playable after one online visit) and that local board generation (`GraphBoardGenerator`) is retained only for the future "Generar nivel" feature (front#36), not the campaign.
- Keep the edit factual and scoped; do not document unbuilt features.

- [ ] **Step 2: Run the full Definition of Done**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter gen-l10n`
Run: `flutter analyze`
Expected: `No issues found!` (whole project).
Run: `flutter test`
Expected: **all** suites green.

If anything fails, fix within the relevant fragment's scope (do not introduce out-of-scope changes) and re-run.

- [ ] **Step 3: Comment on the issue (scope redefinition)**

Post a comment on **MazePruebaFront#8** documenting the redefinition of scope: front#8 is now THE back↔front level-integration issue — the campaign plays the back's official levels (remote catalog, offline cache, catalog-ordered "next"), replacing local generation. Reference this plan (`docs/superpowers/plans/2026-07-11-front8-remote-levels-integration.md`) and the spec commit `917fd4e`. Use `gh issue comment 8 --repo <owner>/MazePruebaFront --body "..."` (confirm the repo slug with `gh repo view` first; if `gh` is unavailable, print the comment text for the user to post).

- [ ] **Step 3b: AI_HISTORY + commit the README**

AI_HISTORY entry title `README: campaña remota + DoD front#8`. Then:

```bash
git add MazePruebaFront/README.md AI_HISTORY.MD
git commit -m "docs(front): document remote campaign and finalize front#8"
```

(The issue comment is a GitHub action, not a file change; it is not part of this commit.)

---

## Plan self-review

Checked against the spec (`2026-07-11-front8-remote-levels-integration-design.md`) with fresh eyes:

- **§3 Domain** — `Level` VO (Task 1), `LevelFailure` sealed (Task 2), `ILevelRepository` minimal port with no prefetch method (Task 2). ✔
- **§4 Infrastructure** — `LevelRemoteDataSource` raw + propagates `DioException` (Task 4); strict `LevelJsonDecoder` symmetric to the encoder with the golden property (Task 3); Hive `levels_cache` storing raw JSON, keys `catalog`/`level:<id>`, opened at startup, no TTL (Task 5 + Task 7 §5.3 box open); `RemoteLevelRepository` network-first with the four getLevel rules + `DioException` dying + `ILoggerService` logging (Task 5). ✔
- **§5 Application** — `levelCatalogProvider` AsyncNotifier with sequential unawaited background prefetch that swallows individual failures + `refresh()` (Task 6); `GameController.loadLevel` async-remote reusing the `AsyncValue` wrapper (no new sealed case), restart without refetch, undo-after-win via `_currentLevelData`, generator/`LevelBlueprint`/`levelId.number` removed from the campaign flow while the generator itself is kept (Task 7); DI wiring (Task 7 §5.3). ✔
- **§6 Presentation** — `LevelSelectionScreen` loading/error-retry/data grid, position label vs real `LevelId` navigation (Task 8); `GameScreen` error branch discriminates `LevelUnavailable` (retry) vs `LevelNotFound`/`LevelCorrupted` (terminal) (Task 10); `VictoryScreen` next-from-Catálogo + last-level copy, no new screen (Task 9); new l10n keys en/es added by their consuming fragments (Tasks 8–10). ✔
- **§7 Tests** — every required test group is a `qa` subagent prompt (Level VO, decoder golden + ~5 corrupt, repo six getLevel + catalog cases, catalog provider incl. prefetch resilience, GameController remote/restart/timer/optimal, three widget suites; the contract/golden test is folded into the decoder's golden round-trip against the CONTEXT-MAP example). ✔
- **§8 No-objetivos** — no progress migration, no unlock system, no cache TTL, `LevelBlueprint`/`GraphBoardGenerator` and their tests untouched, no `LevelId.next()`/`.number` fix. ✔
- **§9 Housekeeping** — per-fragment Conventional Commits + AI_HISTORY, README update, issue comment, final DoD (Task 11). ✔

Type consistency verified across tasks: `Level({required LevelId id, required ArrowBoard board, int? timeLimitSec})`, `ArrowBoard({required arrows, required cols, required rows})`, `Arrow({required id, required cells, required headDirection})`, `LevelJsonDecoder.decode(Map<String,Object?>)`, `ILevelRepository.{listLevelIds,getLevel}`, `LevelCacheDataSource.{readCatalog,writeCatalog,readLevel,writeLevel}`, `LevelRemoteDataSource.{fetchLevelIds,fetchLevel}`, `GameController(ILevelRepository, RemoveArrowUseCase, CommandInvoker, [ITicker])`, `LevelCatalogNotifier(ILevelRepository, ILoggerService)` — all consistent between producing and consuming tasks.
