# BoardSpace (front#73, ADR-0005) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce `BoardSpace` — a deep domain module owning the tablero's geometry (adjacency, exit lanes, frontier) — so `Direction`/`Position` arithmetic that is today duplicated across `Arrow`, `GraphBoardGenerator`, and three presentation switches collapses into one seam, with a second test-only implementation (`HoledRectSpace`) proving the abstraction is real (OCP).

**Architecture:** Add `lib/domain/game_core/space/{board_space.dart,rect_space.dart}` (abstract class with template methods `areAdjacent`/`exitLane`, built on primitives `contains`/`step`; `RectSpace` is the only production implementation and owns the single Direction→delta switch in the whole artifact). `ArrowBoard` holds `space: BoardSpace` instead of raw `cols`/`rows` fields (delegated getters preserve every existing reader). `Arrow` becomes pure data. The generator and decoder are rewired onto `space`; the wire format, the 3(4) presentation switches collapse into one projection helper, painters/widgets keep receiving primitives (never a `BoardSpace`).

**Tech Stack:** Flutter/Dart, `equatable` (^2.0.7, already a dependency), `flutter_test`, no new packages.

## Global Constraints

- **Wire format is frozen**: `cols`/`rows` int keys, `[row,col]` position pairs, `headDir` strings — decoder/encoder inputs/outputs must be byte-identical to today.
- **Generator determinism is a hard constraint, not a style preference**: for a fixed `seed`, the exact sequence of `Random` calls (and their order) must not change. The campaign's 15 curated levels + 3 themed levels are reproduced byte-for-byte from `(tier, seed)` via `tool/level_production/produce.dart`/`produce_themed.dart` — see `../../../../MazePruebaBack/prisma/levels/manifest.md` in the back repo for the frozen seed set this protects. Task 1's golden-boards fixture is the enforcement mechanism: it must stay green after every later task.
- **`BoardSpace` is never mocked** — it is a pure domain value; tests build real `RectSpace`/`HoledRectSpace` instances.
- **Painters/widgets keep receiving primitives** (`cols`, `rows`, `Position`, `Direction`) — never a `BoardSpace` reference. The projection helper (Task 6) is presentation-side arithmetic, not a domain dependency.
- **Acceptance gate (verify in Task 8, not before)**: zero `switch`/pattern-match on `Direction` anywhere in `lib/` outside `RectSpace.step`, `level_json_decoder.dart`/`level_json_encoder.dart` (wire codec), and `lib/presentation/game/direction_projection.dart`. Zero direction/adjacency/bounds arithmetic outside `lib/domain/game_core/space/` in `domain/`, `application/`, `infrastructure/` (codec excluded). `flutter analyze` clean; full `flutter test` suite green (currently 631 tests, all passing on this branch's baseline).
- **Deviation from the issue's assumption (re-inventory finding, verified 2026-07-15)**: `tool/level_production/` (front#65/#68 tooling) contains **zero** direction/adjacency/bounds arithmetic of its own — every file that touches `Position` does so via plain 2D grid-index construction or `Set<Position>` membership, and all path generation is delegated to `GraphBoardGenerator`. The issue's point 4 ("tooling migration is in scope") does not apply — there is nothing there to migrate. No task in this plan touches `tool/level_production/*.dart` production logic (Task 1 only *reads* its output to capture a fixture).
- Package name: `flutter_arrow_maze`. Test imports use `package:flutter_arrow_maze/...`; imports of `test/support/*.dart` helpers are relative (that directory is not part of the package).
- `Position`'s constructor is **not const** (it validates `row >= 0 && col >= 0` in its body, throwing `InvalidPositionException` otherwise) — never write `const Position(...)` anywhere in this plan or its code. `ArrowId`, `RectSpace`, and `Arrow` constructors **are** const-declared; call sites containing a non-const `Position` simply omit the `const` keyword (legal Dart — a const-declared constructor doesn't force const call sites).
- One Conventional Commit + one `AI_HISTORY.MD` entry per task below. The last entry on `main` is **077**; this plan's entries start at **078** (re-verify the number is still current when executing — another branch may have merged since planning). Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` per project convention (`CLAUDE.md`).
- Branch: `feat/#73-boardspace` (already created from `main` at `7a48816`, worktree at `.claude/worktrees/front73-boardspace`). Never push to `main` directly; PR only, `Closes #73`, user decides on merge.

## File Structure

```
lib/domain/game_core/space/
├── board_space.dart          Task 2 — abstract class, template methods
└── rect_space.dart           Task 2 — the one production implementation

lib/presentation/game/
└── direction_projection.dart Task 6 — consolidated direction→screen helper

test/support/
├── board_space_contract_tests.dart  Task 2 — shared contract suite (runs against any BoardSpace)
├── holed_rect_space.dart            Task 3 — test-only second adapter (OCP)
└── arrow_fixtures.dart              Task 4 — straightArrow() test helper (replaces Arrow.straight)

test/domain/game_core/space/
├── rect_space_test.dart             Task 2
└── holed_rect_space_test.dart       Task 3

test/domain/entities/
└── arrow_board_holed_space_certification_test.dart   Task 7 — OCP proof

test/fixtures/golden_boards/
├── cand-t1-s101.json          Task 1 — small-board determinism fixture
└── cand-t5-s918.json          Task 1 — 50×50 finale determinism fixture

test/tool/level_production/
└── golden_boards_regression_test.dart   Task 1
```

Files modified in place (no new files): `lib/domain/arrows/entities/arrow.dart`, `lib/domain/arrows/entities/arrow_board.dart`, `lib/infrastructure/generators/graph_board_generator.dart`, `lib/infrastructure/serialization/level_json_decoder.dart`, `lib/presentation/game/painters/arrow_painter.dart`, `lib/presentation/game/painters/snake_exit_painter.dart`, `lib/presentation/game/widgets/arrow_widget.dart`, `README.md`, plus 23 test files (call-site migration, Task 4) and `test/domain/entities/arrow_test.dart`/`test/domain/entities/arrow_board_test.dart` (test content migration, Task 4).

---

### Task 1: Golden boards regression fixture (pre-refactor characterization)

**Files:**
- Create: `test/fixtures/golden_boards/cand-t1-s101.json`
- Create: `test/fixtures/golden_boards/cand-t5-s918.json`
- Create: `test/tool/level_production/golden_boards_regression_test.dart`

**Interfaces:**
- Consumes: `CandidateSpec`, `produceCandidate` (`tool/level_production/candidate_producer.dart`), `rampStepFor` (`tool/level_production/ramp.dart`) — all pre-existing, unmodified by this task.
- Produces: two fixture files and a test that every later task must keep green. This is a **characterization test, not TDD** — it must pass immediately (nothing is being implemented; current generator behavior is being pinned). Do not expect a RED step.

- [ ] **Step 1: Capture the current (pre-refactor) candidate JSON for both golden seeds**

Run from the repo root of this worktree:

```bash
dart run tool/level_production/produce.dart --tier 1 --seeds 101 --out test/fixtures/golden_boards
dart run tool/level_production/produce.dart --tier 5 --finale --seeds 918 --out test/fixtures/golden_boards
```

This writes `test/fixtures/golden_boards/cand-t1-s101.json`, `cand-t5-s918.json`, plus `manifest-t1.md` and `manifest-t5-finale.md`.

- [ ] **Step 2: Keep only the two JSON fixtures**

```bash
rm test/fixtures/golden_boards/manifest-t1.md test/fixtures/golden_boards/manifest-t5-finale.md
```

Open both `.json` files and sanity-check: `cand-t1-s101.json` has `"cols": 6, "rows": 8`; `cand-t5-s918.json` has `"cols": 50, "rows": 50` and `"order": 5`. Do not hand-edit their contents — they are captured, not authored.

- [ ] **Step 3: Write the regression test**

```dart
// test/tool/level_production/golden_boards_regression_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/level_production/candidate_producer.dart';
import '../../../tool/level_production/ramp.dart';

/// Fija el output del generador para (tier, seed) ANTES del refactor
/// BoardSpace (front#73, ADR-0005). El generador debe seguir produciendo
/// exactamente el mismo JSON durante todo el refactor — mismo seed, misma
/// secuencia de llamadas a Random, mismo tablero. Si este test rompe en
/// cualquier tarea posterior, el refactor tiene un bug de reproducibilidad:
/// NO se recaptura el golden, se corrige el código.
void main() {
  group('golden boards — regresión pre-BoardSpace (front#73)', () {
    test('tier 1, seed 101 (6x8) se mantiene byte-idéntico', () {
      // Arrange
      final spec = CandidateSpec(step: rampStepFor(1), seed: 101);
      final golden =
          File('test/fixtures/golden_boards/cand-t1-s101.json').readAsStringSync();

      // Act
      final result = produceCandidate(spec);

      // Assert
      expect(result.json, golden);
    });

    test('tier 5 finale, seed 918 (50x50) se mantiene byte-idéntico', () {
      // Arrange
      final spec = CandidateSpec(step: rampStepFor(5, finale: true), seed: 918);
      final golden =
          File('test/fixtures/golden_boards/cand-t5-s918.json').readAsStringSync();

      // Act
      final result = produceCandidate(spec);

      // Assert
      expect(result.json, golden);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
```

- [ ] **Step 4: Run the test to confirm it passes immediately**

Run: `flutter test test/tool/level_production/golden_boards_regression_test.dart`
Expected: `2/2 passing` (this is characterization — it must be green from the start, since the generator hasn't changed yet).

- [ ] **Step 5: Update `AI_HISTORY.MD` and commit together with the code**

Append Entrada 078 to `AI_HISTORY.MD` (title "front#73 (fragmento 1) — Golden boards del generador") following the file's established entry structure (Fecha, Tarea o problema abordado, Herramienta de IA utilizada, Prompt o instrucción proporcionada, Resultado obtenido, Modificaciones realizadas por el equipo). `AI_HISTORY.MD` is committed **in the same commit** as the code it documents (confirmed convention: this repo's fragment commits bundle both, never a docs-only follow-up commit for a single fragment).

```bash
git add AI_HISTORY.MD test/fixtures/golden_boards/cand-t1-s101.json test/fixtures/golden_boards/cand-t5-s918.json test/tool/level_production/golden_boards_regression_test.dart
git commit -m "$(cat <<'EOF'
test(tool): pin generator output for (tier1,seed101) and (tier5-finale,seed918)

Golden boards fixture protecting generator determinism through the
upcoming BoardSpace refactor (front#73, ADR-0005).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `BoardSpace` + `RectSpace` + contract tests

**Files:**
- Create: `lib/domain/game_core/space/board_space.dart`
- Create: `lib/domain/game_core/space/rect_space.dart`
- Create: `test/support/board_space_contract_tests.dart`
- Create: `test/domain/game_core/space/rect_space_test.dart`

**Interfaces:**
- Consumes: `Direction` (`lib/domain/game_core/value_objects/direction.dart`, closed 4-value enum, zero behavior today), `Position` (`lib/domain/game_core/value_objects/position.dart`, throws `InvalidPositionException` on negative row/col — never construct one with negative coordinates).
- Produces: `BoardSpace` (abstract, `directions`/`contains`/`step`/`cellCount`/`allCells` primitives + `areAdjacent`/`exitLane` template methods) and `RectSpace(int cols, int rows)` — both consumed by every later task. `runBoardSpaceContractTests(String label, BoardSpace Function() build, {required Position insideNearOrigin, required Position insideAwayFromEdges})` — a reusable test suite Task 3 will invoke a second time against `HoledRectSpace` without modification.

- [ ] **Step 1: Write `BoardSpace`**

```dart
// lib/domain/game_core/space/board_space.dart
import 'package:equatable/equatable.dart';

import '../value_objects/direction.dart';
import '../value_objects/position.dart';

/// Geometría del tablero como concepto propio (ADR-0005 D1/D2): qué celdas
/// existen, cuáles son adyacentes, qué es un carril recto y dónde está la
/// frontera por la que una flecha sale. Único intérprete de [Direction] junto
/// con sus implementaciones concretas — nadie más hace aritmética dr/dc.
abstract class BoardSpace extends Equatable {
  const BoardSpace();

  /// Direcciones válidas en este espacio.
  Iterable<Direction> get directions;

  /// True si [pos] pertenece al espacio.
  bool contains(Position pos);

  /// Celda vecina de [pos] en [dir], o null si cae fuera del espacio.
  Position? step(Position pos, Direction dir);

  /// Cantidad total de celdas del espacio.
  int get cellCount;

  /// Todas las celdas del espacio, en orden canónico row-major (row asc,
  /// luego col asc) — contrato del módulo, no un detalle de implementación.
  Iterable<Position> get allCells;

  /// True si existe una dirección que lleva de [a] a [b] en un paso.
  bool areAdjacent(Position a, Position b) {
    for (final dir in directions) {
      if (step(a, dir) == b) return true;
    }
    return false;
  }

  /// Celdas que hay que recorrer desde [head] en [dir] hasta la frontera del
  /// espacio, en orden cercano→frontera. Excluye [head].
  List<Position> exitLane(Position head, Direction dir) {
    final lane = <Position>[];
    var current = step(head, dir);
    while (current != null) {
      lane.add(current);
      current = step(current, dir);
    }
    return lane;
  }
}
```

- [ ] **Step 2: Write `RectSpace`**

```dart
// lib/domain/game_core/space/rect_space.dart
import '../value_objects/direction.dart';
import '../value_objects/position.dart';
import 'board_space.dart';

/// Espacio rectangular cols×rows: la única geometría de producción hoy.
/// Contiene el único switch dirección→delta del artefacto (ADR-0005 D2),
/// dentro de [step], guardado por [contains] — nunca construye una [Position]
/// con coordenadas negativas (lanzaría InvalidPositionException).
class RectSpace extends BoardSpace {
  final int cols;
  final int rows;

  const RectSpace(this.cols, this.rows);

  @override
  Iterable<Direction> get directions => Direction.values;

  @override
  bool contains(Position pos) =>
      pos.row >= 0 && pos.row < rows && pos.col >= 0 && pos.col < cols;

  @override
  Position? step(Position pos, Direction dir) {
    final (dr, dc) = switch (dir) {
      Direction.up => (-1, 0),
      Direction.down => (1, 0),
      Direction.left => (0, -1),
      Direction.right => (0, 1),
    };
    final nextRow = pos.row + dr;
    final nextCol = pos.col + dc;
    if (nextRow < 0 || nextCol < 0) return null;
    final next = Position(row: nextRow, col: nextCol);
    return contains(next) ? next : null;
  }

  @override
  int get cellCount => cols * rows;

  @override
  Iterable<Position> get allCells sync* {
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        yield Position(row: row, col: col);
      }
    }
  }

  @override
  List<Object?> get props => [cols, rows];
}
```

- [ ] **Step 3: Write the shared contract-test suite**

```dart
// test/support/board_space_contract_tests.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/board_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Suite de contrato compartida (ADR-0005 D7): cualquier [BoardSpace]
/// correcto debe cumplirla. Se corre contra RectSpace (Task 2) y contra
/// HoledRectSpace (Task 3, certificación OCP) sin que este código cambie —
/// solo el espacio bajo prueba y las posiciones de muestra que el llamador
/// garantiza libres de agujeros.
void runBoardSpaceContractTests(
  String label,
  BoardSpace Function() build, {
  required Position insideNearOrigin,
  required Position insideAwayFromEdges,
}) {
  group('BoardSpace contract — $label', () {
    test('contains es true dentro del espacio y false lejos de sus límites', () {
      final space = build();
      expect(space.contains(insideNearOrigin), isTrue);
      expect(space.contains(Position(row: 10000, col: 10000)), isFalse);
    });

    test('step devuelve la celda vecina cuando cae dentro del espacio', () {
      final space = build();
      final next = space.step(insideAwayFromEdges, Direction.right);
      expect(next, isNotNull);
      expect(next, isNot(equals(insideAwayFromEdges)));
      expect(space.contains(next!), isTrue);
    });

    test('step devuelve null cuando la vecina cae fuera del espacio', () {
      final space = build();
      final origin = Position(row: 0, col: 0);
      expect(space.step(origin, Direction.up), isNull);
      expect(space.step(origin, Direction.left), isNull);
    });

    test('areAdjacent es true solo para vecinos alcanzables por step', () {
      final space = build();
      final next = space.step(insideAwayFromEdges, Direction.down);
      expect(next, isNotNull);
      expect(space.areAdjacent(insideAwayFromEdges, next!), isTrue);
      expect(space.areAdjacent(insideAwayFromEdges, insideAwayFromEdges), isFalse);
    });

    test('exitLane excluye la cabeza y termina en la frontera', () {
      final space = build();
      final lane = space.exitLane(insideAwayFromEdges, Direction.right);
      expect(lane, isNot(contains(insideAwayFromEdges)));
      expect(lane, isNotEmpty);
      expect(space.step(lane.last, Direction.right), isNull);
    });

    test('allCells está en orden canónico row-major (row asc, col asc)', () {
      final space = build();
      final cells = space.allCells.toList();
      final sorted = [...cells]
        ..sort((a, b) {
          final byRow = a.row.compareTo(b.row);
          return byRow != 0 ? byRow : a.col.compareTo(b.col);
        });
      expect(cells, equals(sorted));
    });
  });
}
```

- [ ] **Step 4: Write `RectSpace`'s own tests, invoking the shared suite plus rectangle-specific cases**

```dart
// test/domain/game_core/space/rect_space_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../../support/board_space_contract_tests.dart';

void main() {
  runBoardSpaceContractTests(
    'RectSpace',
    () => RectSpace(6, 8),
    insideNearOrigin: Position(row: 0, col: 0),
    insideAwayFromEdges: Position(row: 3, col: 3),
  );

  group('RectSpace — geometría rectangular específica', () {
    test('contains es false para coordenadas fuera de cols/rows', () {
      final space = RectSpace(4, 4);
      expect(space.contains(Position(row: 0, col: 4)), isFalse);
      expect(space.contains(Position(row: 4, col: 0)), isFalse);
    });

    test('directions expone las 4 direcciones cerradas', () {
      final space = RectSpace(4, 4);
      expect(space.directions, containsAll(Direction.values));
      expect(space.directions.length, 4);
    });

    test('cellCount es cols * rows', () {
      expect(RectSpace(6, 8).cellCount, 48);
    });

    test('allCells enumera exactamente cols*rows celdas únicas dentro del espacio', () {
      final space = RectSpace(3, 2);
      final cells = space.allCells.toSet();
      expect(cells.length, 6);
      expect(cells.every(space.contains), isTrue);
    });

    test('exitLane hacia la derecha desde el borde izquierdo cruza todo el ancho', () {
      final space = RectSpace(5, 5);
      final lane = space.exitLane(Position(row: 2, col: 0), Direction.right);
      expect(lane, [
        Position(row: 2, col: 1),
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
        Position(row: 2, col: 4),
      ]);
    });

    test('exitLane hacia arriba desde el borde inferior cruza toda la altura', () {
      final space = RectSpace(5, 5);
      final lane = space.exitLane(Position(row: 4, col: 1), Direction.up);
      expect(lane, [
        Position(row: 3, col: 1),
        Position(row: 2, col: 1),
        Position(row: 1, col: 1),
        Position(row: 0, col: 1),
      ]);
    });

    test('exitLane está vacío cuando la cabeza ya está en la frontera (cada dirección)', () {
      final space = RectSpace(4, 4);
      expect(space.exitLane(Position(row: 0, col: 3), Direction.right), isEmpty);
      expect(space.exitLane(Position(row: 0, col: 0), Direction.left), isEmpty);
      expect(space.exitLane(Position(row: 3, col: 0), Direction.down), isEmpty);
      expect(space.exitLane(Position(row: 0, col: 0), Direction.up), isEmpty);
    });

    test('dos RectSpace con las mismas dimensiones son iguales por valor', () {
      expect(RectSpace(6, 8), equals(RectSpace(6, 8)));
      expect(RectSpace(6, 8), isNot(equals(RectSpace(8, 6))));
    });
  });
}
```

- [ ] **Step 5: Run the new tests**

Run: `flutter test test/domain/game_core/space/rect_space_test.dart`
Expected: all passing (this is new code with no prior behavior to break — ordinary TDD would write the test first, but since `RectSpace` doesn't exist yet, write both together and confirm green here).

- [ ] **Step 6: Run the golden boards test (Task 1) to confirm nothing else broke**

Run: `flutter test test/tool/level_production/golden_boards_regression_test.dart`
Expected: still 2/2 passing (this task didn't touch the generator).

- [ ] **Step 7: Update `AI_HISTORY.MD` (Entrada 079, "front#73 (fragmento 2) — BoardSpace + RectSpace") and commit together with the code**

```bash
git add AI_HISTORY.MD lib/domain/game_core/space/board_space.dart lib/domain/game_core/space/rect_space.dart test/support/board_space_contract_tests.dart test/domain/game_core/space/rect_space_test.dart
git commit -m "$(cat <<'EOF'
feat(domain): add BoardSpace and RectSpace (ADR-0005 D1-D2)

BoardSpace concentrates board geometry (adjacency, exit lanes, frontier)
behind step/contains primitives with areAdjacent/exitLane template
methods. RectSpace is the sole production implementation and owns the
single Direction->delta switch in the artifact.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `HoledRectSpace` (test-only) + shared contract run against it

**Files:**
- Create: `test/support/holed_rect_space.dart`
- Create: `test/domain/game_core/space/holed_rect_space_test.dart`

**Interfaces:**
- Consumes: `RectSpace`, `runBoardSpaceContractTests` (Task 2).
- Produces: `HoledRectSpace(int cols, int rows, {required Set<Position> holes})` — consumed by Task 7's OCP certification test.

- [ ] **Step 1: Write `HoledRectSpace`**

```dart
// test/support/holed_rect_space.dart
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Doble de certificación (ADR-0005 D2/D7, test-only): un RectSpace con
/// celdas removidas. El carril hereda de RectSpace y termina en el agujero
/// — el agujero es frontera, igual que el borde del tablero. Sobreescribe
/// SOLO `contains` (regla del ADR: un segundo adapter real, sin tocar nada
/// más). `allCells`/`cellCount` deliberadamente NO restan los agujeros: esto
/// no es una implementación de producción, es la prueba de que el resto del
/// dominio funciona sobre cualquier BoardSpace sin cambios (OCP).
class HoledRectSpace extends RectSpace {
  final Set<Position> holes;

  const HoledRectSpace(super.cols, super.rows, {required this.holes});

  @override
  bool contains(Position pos) => super.contains(pos) && !holes.contains(pos);

  @override
  List<Object?> get props => [...super.props, holes];
}
```

- [ ] **Step 2: Write `HoledRectSpace`'s tests, invoking the shared suite plus hole-specific cases**

```dart
// test/domain/game_core/space/holed_rect_space_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../../support/board_space_contract_tests.dart';
import '../../../support/holed_rect_space.dart';

void main() {
  runBoardSpaceContractTests(
    'HoledRectSpace',
    () => HoledRectSpace(6, 8, holes: {Position(row: 5, col: 5)}),
    insideNearOrigin: Position(row: 0, col: 0),
    insideAwayFromEdges: Position(row: 2, col: 2),
  );

  group('HoledRectSpace — el agujero es frontera', () {
    test('contains es false para una celda agujereada dentro de los límites', () {
      final space = HoledRectSpace(6, 8, holes: {Position(row: 3, col: 3)});
      expect(space.contains(Position(row: 3, col: 3)), isFalse);
      expect(space.contains(Position(row: 3, col: 2)), isTrue);
    });

    test('exitLane termina antes del agujero, no lo incluye', () {
      final space = HoledRectSpace(6, 8, holes: {Position(row: 2, col: 4)});
      final lane = space.exitLane(Position(row: 2, col: 1), Direction.right);
      expect(lane, [
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
      ]);
      expect(lane, isNot(contains(Position(row: 2, col: 4))));
    });

    test('step hacia un agujero devuelve null, igual que hacia fuera del tablero', () {
      final space = HoledRectSpace(6, 8, holes: {Position(row: 1, col: 1)});
      expect(space.step(Position(row: 1, col: 0), Direction.right), isNull);
    });
  });
}
```

- [ ] **Step 3: Run the new tests**

Run: `flutter test test/domain/game_core/space/holed_rect_space_test.dart`
Expected: all passing, including the 6 shared-contract cases running a second time (now against `HoledRectSpace`) with zero changes to the contract-test file itself.

- [ ] **Step 4: Update `AI_HISTORY.MD` (Entrada 080, "front#73 (fragmento 3) — HoledRectSpace + contract-test compartido") and commit together with the code**

```bash
git add AI_HISTORY.MD test/support/holed_rect_space.dart test/domain/game_core/space/holed_rect_space_test.dart
git commit -m "$(cat <<'EOF'
test(domain): add HoledRectSpace test double (ADR-0005 D2/D7)

Second BoardSpace adapter, test-only: overrides only contains, proving
the seam is real (one adapter = hypothetical, two = real). Shared
contract suite now runs against both RectSpace and HoledRectSpace
unmodified.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `Arrow` becomes pure data + `ArrowBoard` holds `space` + migrate every call site

**Context:** This is the largest mechanical task in the plan. `Arrow.exitPath` and `Arrow.straight` are removed from production domain code; `ArrowBoard`'s constructor changes shape from `{cols, rows}` to `{space}`. Because Dart requires whole-tree compilation consistency, every caller of the removed members must be fixed in this same task — 7 `lib/` files construct `ArrowBoard(cols:, rows:)` today, 23 `test/` files construct `ArrowBoard(...)` and/or call `Arrow.straight(...)`. This includes `lib/infrastructure/generators/graph_board_generator.dart`, which Task 5 will rewrite far more deeply afterward — the fix here is the **minimal patch** needed to keep it compiling; Task 5 supersedes it with the full `space`-based rewrite.

**Files:**
- Modify: `lib/domain/arrows/entities/arrow.dart` (remove `exitPath`, remove `Arrow.straight`)
- Modify: `lib/domain/arrows/entities/arrow_board.dart` (hold `space`, delegated `cols`/`rows` getters, `canExit` via `space.exitLane`)
- Modify: `lib/application/commands/remove_arrow_command.dart:29`
- Modify: `lib/application/state/game_controller.dart:255`
- Modify: `lib/infrastructure/generators/graph_board_generator.dart` (minimal patch only — 2 `ArrowBoard(...)` sites + 1 assertion + 1 import)
- Modify: `lib/infrastructure/serialization/level_json_decoder.dart:34`
- Create: `test/support/arrow_fixtures.dart` (`straightArrow()` helper, replaces `Arrow.straight`)
- Modify: 23 test files (table below) — mechanical `ArrowBoard(cols:,rows:)` → `ArrowBoard(space: RectSpace(cols,rows))` and/or `Arrow.straight(` → `straightArrow(` substitutions
- Modify: `test/domain/entities/arrow_test.dart` (delete the `exitPath` test group — coverage moved to `rect_space_test.dart` in Task 2; delete `Arrow.straight` usages via the helper)
- Modify: `test/domain/entities/arrow_board_test.dart` (add the two relocated wiring tests described in Step 6)

**Interfaces:**
- Consumes: `BoardSpace`, `RectSpace` (Task 2).
- Produces: `ArrowBoard({required List<Arrow> arrows, required BoardSpace space})`, delegated `ArrowBoard.cols`/`.rows` getters (unchanged reader contract for every widget/encoder/test that only *reads* them), `straightArrow({required ArrowId id, required Position tail, required Direction direction, required int length, String? paintRole})` (test/support). Task 5 (generator), Task 6 (presentation — reads `.cols`/`.rows`, no change needed), Task 7 (OCP test) all build on this shape.

- [ ] **Step 1: Rewrite `Arrow` as pure data**

Replace the entire contents of `lib/domain/arrows/entities/arrow.dart` with:

```dart
// lib/domain/arrows/entities/arrow.dart
import 'package:equatable/equatable.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';

/// Flecha como CAMINO: `cells` va de la cola (first) a la cabeza (last), con
/// celdas ortogonalmente adyacentes y sin repetir. Una flecha recta es el caso
/// degenerado (sin curvas). `headDirection` es la dirección por la que la cabeza
/// abandona el tablero (mecánica "serpiente": el cuerpo se retrae por su propio
/// camino, así que la salida solo depende del carril recto frente a la cabeza).
///
/// Dato puro (ADR-0005 D2/D6): no conoce el espacio del tablero. El carril de
/// salida es responsabilidad de `BoardSpace.exitLane` (ver
/// `ArrowBoard.canExit`); construir una flecha recta para tests es
/// responsabilidad de `straightArrow` en `test/support/arrow_fixtures.dart`
/// (el único llamador de la antigua `Arrow.straight` era el propio código de
/// test — la producción nunca la usó).
class Arrow extends Equatable {
  final ArrowId id;
  final List<Position> cells;
  final Direction headDirection;

  /// Rol de pintado (Instrucciones de pintado, ADR 0004): dato OPACO servido por
  /// niveles temáticos que asocia esta flecha a un color de la `palette` del
  /// `Level`. Nulo en campaña. No participa en la mecánica (salida/solubilidad);
  /// solo lo consume el seam de color en presentación (front#67).
  final String? paintRole;

  const Arrow({
    required this.id,
    required this.cells,
    required this.headDirection,
    this.paintRole,
  });

  Position get head => cells.last;
  Position get tail => cells.first;
  Direction get direction => headDirection; // compat para widgets/animaciones
  int get length => cells.length;

  @override
  List<Object?> get props => [id, cells, headDirection, paintRole];
}
```

- [ ] **Step 2: Rewrite `ArrowBoard` to hold `space`**

Replace the entire contents of `lib/domain/arrows/entities/arrow_board.dart` with:

```dart
// lib/domain/arrows/entities/arrow_board.dart
import 'package:equatable/equatable.dart';
import 'arrow.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/space/board_space.dart';
import '../../game_core/space/rect_space.dart';
import '../../game_core/value_objects/position.dart';

// Aggregate Root: único punto de acceso al estado del tablero de flechas.
class ArrowBoard extends Equatable {
  final List<Arrow> arrows;
  final BoardSpace space;

  const ArrowBoard({
    required this.arrows,
    required this.space,
  });

  // cols/rows delegados (ADR-0005 D4): todo espacio concreto de HOY (RectSpace
  // y su único subtipo HoledRectSpace) tiene bounding box rectangular, así que
  // exponer cols/rows aquí evita tocar cada widget/encoder que ya los lee. No
  // es parte del contrato de BoardSpace — un espacio no-rectangular futuro
  // rompería este cast a propósito (documentado, no implementado: ADR-0005 §8).
  int get cols => (space as RectSpace).cols;
  int get rows => (space as RectSpace).rows;

  // Caché de ocupación por instancia (#64): ArrowBoard es inmutable, así que
  // el Set de celdas ocupadas se computa lazy UNA vez por instancia en lugar
  // de reconstruirse en cada canExit/overlaps. Se usa un Expando estático (y
  // no un campo `late final`) para conservar el constructor const — parte de
  // la interface pública (hay consumidores que construyen en contexto const).
  // removeArrow devuelve una instancia nueva, cuyo caché se recomputa lazy
  // una vez (O(N) por toque, aceptable). El Expando no impide el GC de los
  // tableros descartados.
  static final Expando<Set<Position>> _occupiedCache =
      Expando<Set<Position>>('ArrowBoard occupancy');

  Set<Position> get _occupied =>
      _occupiedCache[this] ??= {for (final a in arrows) ...a.cells};

  bool get isCleared => arrows.isEmpty;

  bool contains(ArrowId id) => _findById(id) != null;

  Arrow? arrowById(ArrowId id) => _findById(id);

  Arrow? arrowAt(Position pos) {
    for (final a in arrows) {
      if (a.cells.contains(pos)) return a;
    }
    return null;
  }

  Arrow? _findById(ArrowId id) {
    for (final a in arrows) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool overlaps(Arrow arrow) {
    final ownCells = _findById(arrow.id)?.cells.toSet() ?? const <Position>{};
    return arrow.cells.any((c) => _occupied.contains(c) && !ownCells.contains(c));
  }

  bool canExit(ArrowId id) {
    final arrow = _findById(id);
    if (arrow == null) return false;
    // Mecánica serpiente: el cuerpo se retrae por su propio camino, así que
    // las celdas de la PROPIA flecha nunca bloquean su salida (una serpiente
    // doblada puede tener cuerpo geométricamente delante de la cabeza).
    final ownCells = arrow.cells.toSet();
    return space
        .exitLane(arrow.head, arrow.headDirection)
        .every((p) => !_occupied.contains(p) || ownCells.contains(p));
  }

  ArrowBoard removeArrow(ArrowId id) {
    return ArrowBoard(
      arrows: arrows.where((a) => a.id != id).toList(),
      space: space,
    );
  }

  @override
  List<Object?> get props => [arrows, space];
}
```

- [ ] **Step 3: Add the `straightArrow` test helper**

```dart
// test/support/arrow_fixtures.dart
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

/// Fixture de test: flecha recta de `length` celdas desde `tail` en
/// `direction`. Reemplaza al antiguo `Arrow.straight` (ADR-0005 D6: Arrow es
/// dato puro en producción; esta conveniencia solo tenía consumidores en
/// test/, así que se muda aquí en vez de recibir un BoardSpace — no hay
/// ningún llamador de producción que perder).
Arrow straightArrow({
  required ArrowId id,
  required Position tail,
  required Direction direction,
  required int length,
  String? paintRole,
}) {
  assert(length >= 1, 'length must be >= 1');
  final cells = List<Position>.generate(length, (i) => switch (direction) {
        Direction.right => Position(row: tail.row, col: tail.col + i),
        Direction.left => Position(row: tail.row, col: tail.col - i),
        Direction.down => Position(row: tail.row + i, col: tail.col),
        Direction.up => Position(row: tail.row - i, col: tail.col),
      });
  return Arrow(id: id, cells: cells, headDirection: direction, paintRole: paintRole);
}
```

- [ ] **Step 4: Fix the 4 non-test `lib/` call sites that aren't `arrow.dart`/`arrow_board.dart` themselves**

`lib/application/commands/remove_arrow_command.dart:29` — change:
```dart
ArrowBoard(arrows: [...board.arrows, _removedArrow!], cols: board.cols, rows: board.rows)
```
to:
```dart
ArrowBoard(arrows: [...board.arrows, _removedArrow!], space: board.space)
```

`lib/application/state/game_controller.dart:255` — change:
```dart
ArrowBoard(arrows: const [], cols: data.board.cols, rows: data.board.rows)
```
to:
```dart
ArrowBoard(arrows: const [], space: data.board.space)
```

`lib/infrastructure/serialization/level_json_decoder.dart:34` — inside `_decodeStrict`, change:
```dart
      board: ArrowBoard(
        arrows: arrows,
        cols: _int(json, 'cols'),
        rows: _int(json, 'rows'),
      ),
```
to:
```dart
      board: ArrowBoard(
        arrows: arrows,
        space: RectSpace(_int(json, 'cols'), _int(json, 'rows')),
      ),
```
and add the import `import '../../domain/game_core/space/rect_space.dart';` at the top of the file. This is the decoder's full migration (wire format unchanged — it still reads `cols`/`rows` as ints from the JSON, only the intermediate `ArrowBoard` construction changes); `level_json_encoder.dart` needs **no changes** — it reads `board.cols`/`board.rows`, which remain valid via the delegated getters added in Step 2.

`lib/infrastructure/generators/graph_board_generator.dart` — minimal patch (Task 5 replaces this file wholesale, but the codebase must compile after this task): add the import `import '../../domain/game_core/space/rect_space.dart';`, then:

change (line ~69-72):
```dart
      assert(
          candidate
              .exitPath(cols, rows)
              .every((p) => !occupied.contains(p)),
          'candidate exit lane is blocked at placement time');
```
to:
```dart
      assert(
          RectSpace(cols, rows)
              .exitLane(candidate.head, candidate.headDirection)
              .every((p) => !occupied.contains(p)),
          'candidate exit lane is blocked at placement time');
```

change (line ~86):
```dart
    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
```
to:
```dart
    return ArrowBoard(arrows: placed, space: RectSpace(cols, rows));
```

change (line ~142, inside `generateThemed`):
```dart
    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
```
to:
```dart
    return ArrowBoard(arrows: placed, space: RectSpace(cols, rows));
```

- [ ] **Step 5: Migrate every test file's `ArrowBoard(...)` and `Arrow.straight(...)` call sites**

For each file below: if it constructs `ArrowBoard(..., cols: X, rows: Y, ...)`, replace with `ArrowBoard(..., space: RectSpace(X, Y), ...)` and add `import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';`. If it calls `Arrow.straight(...)`, replace `Arrow.straight(` with `straightArrow(` (the named-argument list is identical — no other change needed) and add an import of `test/support/arrow_fixtures.dart` at the correct relative depth from the file's own location (e.g. from `test/domain/entities/arrow_test.dart` that's `'../../support/arrow_fixtures.dart'`; from `test/presentation/game/widgets/arrow_widget_test.dart` that's `'../../../support/arrow_fixtures.dart'` — match the file's actual nesting depth under `test/`).

| File | `ArrowBoard(cols:,rows:)` → `space:` | `Arrow.straight(` → `straightArrow(` |
|---|---|---|
| `test/application/commands/command_invoker_test.dart` | yes | yes |
| `test/application/providers/leaderboard_providers_test.dart` | yes | yes |
| `test/application/providers/level_catalog_provider_test.dart` | yes | no |
| `test/application/providers/progress_providers_test.dart` | yes | yes |
| `test/application/state/game_controller_hint_test.dart` | yes | yes |
| `test/application/state/game_controller_test.dart` | yes | yes |
| `test/application/state/generated_game_controller_test.dart` | yes | yes |
| `test/application/use_cases/generate_board_use_case_test.dart` | yes | no |
| `test/application/use_cases/remove_arrow_use_case_test.dart` | yes | yes |
| `test/domain/arrows/value_objects/generated_board_test.dart` | yes | no |
| `test/domain/board/entities/level_test.dart` | yes | no |
| `test/domain/entities/arrow_board_occupancy_test.dart` | yes | yes |
| `test/domain/entities/arrow_board_test.dart` | yes | yes (plus Step 6 additions) |
| `test/domain/entities/arrow_test.dart` | no | yes (plus Step 6 deletions) |
| `test/domain/services/i_level_generator_test.dart` | yes | yes |
| `test/infrastructure/serialization/level_json_encoder_test.dart` | yes | no |
| `test/presentation/game/arrow_color_resolver_test.dart` | no | yes |
| `test/presentation/game/screens/game_screen_hint_test.dart` | yes | yes |
| `test/presentation/game/screens/game_screen_test.dart` | yes | yes |
| `test/presentation/game/widgets/arrow_widget_test.dart` | no | yes |
| `test/presentation/game/widgets/board_widget_test.dart` | yes | yes |
| `test/presentation/generated/generated_result_screen_test.dart` | yes | yes |
| `test/tool/level_production/candidate_producer_test.dart` | yes | no |

After editing, run `flutter analyze`. Every remaining reference to the removed `cols:`/`rows:` named parameters or to `Arrow.straight` shows as a compile error at an exact file:line — fix until analyze is clean (per ADR-0005's own principle: "el compilador es el checklist de migración").

- [ ] **Step 6: Migrate `arrow_test.dart`'s `exitPath` coverage**

In `test/domain/entities/arrow_test.dart`, delete the entire test group(s) exercising `Arrow.exitPath` (the straight-line right/left/down/up cases and their "empty at border" variants — this geometry is now covered by `rect_space_test.dart`'s `exitLane` tests, Task 2) and delete the `'paintRole no altera exitPath'` test (there is no `exitPath` method left to test the invariance of — `paintRole` structurally cannot affect geometry now that `cells`/`headDirection` are the only fields any space computation reads).

The two "headDirection wins over the body's last segment" cases move to `test/domain/entities/arrow_board_test.dart` as `canExit` wiring tests — they no longer test geometry (that's `exitLane`'s job, proven once at the space level), they test that `canExit` reads `headDirection`, not the body's last segment. Add to `arrow_board_test.dart`:

```dart
    test('canExit sigue headDirection (right), no el último segmento del cuerpo (up)', () {
      // Arrange: cuerpo doblado que llega a la cabeza viniendo de "arriba",
      // pero headDirection es "right". Si canExit leyera el último segmento
      // del cuerpo en vez de headDirection, el carril iría hacia (0,2)
      // -ocupado por decoy- y devolvería false en lugar de true.
      final space = RectSpace(6, 6);
      final decoy = Arrow(
        id: ArrowId('decoy'),
        cells: [Position(row: 0, col: 2)],
        headDirection: Direction.up,
      );
      final bent = Arrow(
        id: ArrowId('bent'),
        cells: [
          Position(row: 3, col: 2),
          Position(row: 2, col: 2),
          Position(row: 1, col: 2),
        ],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [bent, decoy], space: space);

      // Act & Assert
      expect(board.canExit(bent.id), isTrue);
    });
```

(Add the necessary imports for `RectSpace`, `Arrow`, `ArrowId`, `Position`, `Direction` if not already present in the file — check the file's existing imports first, most are likely already there since it's an `ArrowBoard`/`Arrow` test file.)

- [ ] **Step 7: Run the full suite**

Run: `flutter analyze` — expect zero errors.
Run: `flutter test` — expect all tests passing (the count will differ slightly from the 631 baseline: several `exitPath`-specific tests were deleted from `arrow_test.dart`, one wiring test was added to `arrow_board_test.dart`, and new space-level tests exist from Tasks 2-3 — net change is expected and fine, the requirement is zero failures).
Run: `flutter test test/tool/level_production/golden_boards_regression_test.dart` — expect 2/2 still passing (this task's generator touch was a behavior-preserving 1:1 substitution).

- [ ] **Step 8: Update `AI_HISTORY.MD` (Entrada 081, "front#73 (fragmento 4) — Arrow dato puro + ArrowBoard sostiene el espacio") and commit together with the code**

This is one large mechanical commit (constructor shape change forces simultaneous call-site migration — see task Context above for why it can't be split further).

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(domain): Arrow becomes pure data, ArrowBoard holds BoardSpace

Arrow.exitPath and Arrow.straight are removed from production code
(ADR-0005 D6) — the former is replaced by ArrowBoard.canExit calling
space.exitLane directly, the latter had no production callers and moves
to test/support/arrow_fixtures.dart as straightArrow(). ArrowBoard's
constructor now takes space: BoardSpace instead of cols/rows (delegated
getters keep every existing reader compiling unchanged). Migrates all
27 ArrowBoard construction sites and 50 Arrow.straight call sites.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Generator internals migrate to `space` (determinism-preserving)

**Context:** `graph_board_generator.dart`'s private `_lane` method is a third reimplementation of the exit-lane arithmetic (after `Arrow.exitPath`, removed in Task 4, and the presentation switches, Task 6). `_freeNeighbors`'s manual bounds checks are also adjacency arithmetic that belongs in the space module per the acceptance criteria. Both must be replaced **without changing RNG call order or candidate ordering** — verified below, not assumed.

**Determinism proof (read before editing, do not skip):**
- `_freeNeighbors`' candidate order today is `[up, down, left, right]` when all four are in-bounds (the `if` guards are checked in that literal order at lines 237-240 of the pre-Task-5 file). `Direction`'s declaration order (`lib/domain/game_core/value_objects/direction.dart`) is `{ up, down, left, right }` — identical. `RectSpace.directions => Direction.values` therefore iterates in the exact same order, so replacing the manual bounds checks with a loop over `space.directions` + `space.step` preserves candidate order exactly.
- `space.step(p, dir) != null` is true iff the manual bounds check for that direction was true — verified per-direction: e.g. "up" manual check is `p.row > 0`; `step` computes `nextRow = p.row - 1`, guards `nextRow < 0` (i.e. returns null iff `p.row <= 0`, i.e. non-null iff `p.row > 0`) — identical. The other three directions follow the same reasoning.
- `space.exitLane(head, dir)` computes the identical cell list as the old `_lane(head, dir, cols, rows)` — both are "step from head in dir, excluding head, until falling outside the space," and `RectSpace.step`/`contains` implement the exact same bounds as the old inline formulas (verified in Task 2).
- The RNG call sequence itself (`rng.nextInt(4)` for direction, then head-sampling `nextInt`s, then `nextInt(maxPathLen-1)`, then per-body-step `nextInt(options.length)`) is untouched — none of the edits below add, remove, or reorder a `rng.nextInt` call.

**Files:**
- Modify: `lib/infrastructure/generators/graph_board_generator.dart` (full-file rewrite below)

**Interfaces:**
- Consumes: `BoardSpace`, `RectSpace` (Task 2), `ArrowBoard(space:)` (Task 4).
- Produces: no new public API — `generate`/`generateThemed` signatures are unchanged (`ILevelGenerator` port untouched).

- [ ] **Step 1: Replace the entire file**

```dart
// lib/infrastructure/generators/graph_board_generator.dart
import 'dart:math';
import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/space/board_space.dart';
import '../../domain/game_core/space/rect_space.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

/// One themed region for [GraphBoardGenerator.generateThemed]: a set of cells
/// that a group of arrows must stay inside, all tagged with one paint role.
class ThemedRegionSpec {
  final String role; // -> Arrow.paintRole and palette key (ADR 0004)
  final Set<Position> cells; // the arrow bodies are confined to these cells
  final int arrowCount; // target arrows to place in this region
  final int maxPathLen;

  const ThemedRegionSpec({
    required this.role,
    required this.cells,
    required this.arrowCount,
    required this.maxPathLen,
  });
}

// DAG: cada flecha se coloca solo si YA puede salir en el momento de colocarla.
// Esto garantiza solubilidad por construcción. La generación es determinista
// cuando se pasa [seed] (mismo seed ⇒ mismo tablero ⇒ restart reproducible).
class GraphBoardGenerator implements ILevelGenerator {
  // AOP: logger opcional para registrar degradación con gracia sin acoplar
  // la lógica de negocio a un logger concreto (DIP). Constructor sin args
  // sigue siendo válido para main.dart y tests.
  final ILoggerService? _logger;

  GraphBoardGenerator({ILoggerService? logger}) : _logger = logger;

  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    assert(maxPathLen >= 2, 'maxPathLen must be >= 2; got $maxPathLen');
    final rng = Random(seed);
    final space = RectSpace(cols, rows);
    final placed = <Arrow>[];
    // Estado interno incremental (#64): las celdas ocupadas por las flechas
    // YA aceptadas se acumulan aquí y se actualizan al aceptar cada flecha,
    // en lugar de reconstruirse (y de instanciar un ArrowBoard temporal) en
    // cada intento — eso hacía inviable un 50×50 denso (~10⁸ operaciones).
    final occupied = <Position>{};
    final maxAttempts = cols * rows * 30;
    var attempts = 0;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final candidate = _randomBentArrow(
          rng, space, cols, rows, placed.length, maxPathLen, occupied);
      if (candidate == null) continue;

      // Válido por construcción contra el estado local: _randomBentArrow
      // elige una cabeza con carril de salida libre de `occupied`, reserva
      // ese carril y crece el cuerpo evitando `occupied` — no hay overlap y
      // la salida queda libre en el momento de colocarla (invariante DAG).
      assert(candidate.cells.every((c) => !occupied.contains(c)),
          'candidate overlaps the incremental occupancy state');
      assert(
          space
              .exitLane(candidate.head, candidate.headDirection)
              .every((p) => !occupied.contains(p)),
          'candidate exit lane is blocked at placement time');

      placed.add(candidate);
      occupied.addAll(candidate.cells);
    }

    if (placed.length < arrowCount) {
      _logger?.warn(
        'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
        'in ${cols}x$rows board after $attempts attempts (seed=$seed)',
        'GraphBoardGenerator',
      );
    }

    return ArrowBoard(arrows: placed, space: space);
  }

  /// Genera un tablero temático (#68): cada [ThemedRegionSpec] confina los
  /// CUERPOS de sus flechas a `region.cells` y las etiqueta con `region.role`
  /// como [Arrow.paintRole]. El carril de salida sigue siendo de tablero
  /// completo (puede cruzar regiones — mecánicamente válido e intencional) y
  /// `occupied` es GLOBAL entre regiones, así que se preserva el invariante
  /// DAG: el tablero entero se vacía en orden inverso de colocación.
  /// NO está en el puerto [ILevelGenerator]: es un extra de infraestructura
  /// que consume el pipeline de producción temática, no la campaña.
  ArrowBoard generateThemed({
    required int cols,
    required int rows,
    required List<ThemedRegionSpec> regions,
    int? seed,
  }) {
    final rng = Random(seed);
    final space = RectSpace(cols, rows);
    final placed = <Arrow>[];
    // GLOBAL entre regiones -> preserva el DAG global (misma disciplina de
    // ocupación + carril que [generate]).
    final occupied = <Position>{};
    var index = 0;

    for (final region in regions) {
      var regionPlaced = 0;
      var attempts = 0;
      final maxAttempts = region.cells.length * 30;
      while (regionPlaced < region.arrowCount && attempts < maxAttempts) {
        attempts++;
        final candidate = _randomBentArrow(
          rng,
          space,
          cols,
          rows,
          index,
          region.maxPathLen,
          occupied,
          allowedBody: region.cells,
          paintRole: region.role,
        );
        if (candidate == null) continue;

        placed.add(candidate);
        occupied.addAll(candidate.cells);
        index++;
        regionPlaced++;
      }
      if (regionPlaced < region.arrowCount) {
        _logger?.warn(
          'themed region "${region.role}": placed $regionPlaced/'
          '${region.arrowCount} arrows (graceful degradation)',
          'GraphBoardGenerator',
        );
      }
    }

    return ArrowBoard(arrows: placed, space: space);
  }

  /// Construye una flecha doblada: elige cabeza+dirección con carril de salida
  /// libre, reserva ese carril, y crece el cuerpo HACIA ATRÁS con una caminata
  /// aleatoria auto-evitante. Devuelve null si no logra un cuerpo de largo >= 2.
  ///
  /// [allowedBody] (#68) confina cabeza y cuerpo a esa región; el carril de
  /// salida NO se confina (sigue siendo de tablero completo). Con
  /// `allowedBody == null` el comportamiento — incluida la secuencia exacta de
  /// llamadas a [rng] — es idéntico al camino de campaña.
  Arrow? _randomBentArrow(Random rng, BoardSpace space, int cols, int rows,
      int index, int maxPathLen, Set<Position> occupied,
      {Set<Position>? allowedBody, String? paintRole}) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final head = _randomHeadWithClearLane(rng, space, cols, rows, dir, occupied,
        allowedBody: allowedBody);
    if (head == null) return null;

    // Reserva el carril de salida para que la flecha nunca bloquee su salida.
    final blocked = <Position>{...occupied, head, ...space.exitLane(head, dir)};

    final body = <Position>[head]; // head..tail; se invierte al final
    final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
    var cursor = head;
    while (body.length < targetLen) {
      final options =
          _freeNeighbors(cursor, space, blocked, allowedBody: allowedBody);
      if (options.isEmpty) break; // acepta cuerpo más corto
      final next = options[rng.nextInt(options.length)];
      body.add(next);
      blocked.add(next);
      cursor = next;
    }
    if (body.length < 2) return null;

    return Arrow(
      id: ArrowId('arrow-$index'),
      cells: body.reversed.toList(), // cola (first) .. cabeza (last)
      headDirection: dir,
      paintRole: paintRole, // null en campaña -> sin cambios
    );
  }

  /// Busca (hasta 20 intentos) una celda-cabeza libre cuyo carril recto al
  /// borde en [dir] esté libre de [occupied].
  ///
  /// Con [allowedBody] (#68) la cabeza se muestrea DESDE la región (eficiencia:
  /// muestrear el tablero completo desperdiciaría los 20 intentos en regiones
  /// pequeñas); el chequeo de carril sigue siendo contra [occupied] global.
  Position? _randomHeadWithClearLane(Random rng, BoardSpace space, int cols,
      int rows, Direction dir, Set<Position> occupied,
      {Set<Position>? allowedBody}) {
    if (allowedBody == null) {
      // Camino de campaña: byte a byte idéntico (misma secuencia de rng). El
      // muestreo aleatorio de índice no es aritmética de espacio (ADR-0005)
      // — usa cols/rows como rango de rng.nextInt, no como chequeo geométrico.
      for (var t = 0; t < 20; t++) {
        final head = Position(row: rng.nextInt(rows), col: rng.nextInt(cols));
        if (occupied.contains(head)) continue;
        final lane = space.exitLane(head, dir);
        if (lane.every((p) => !occupied.contains(p))) return head;
      }
      return null;
    }

    final pool = allowedBody.toList(); // orden de iteración de Set estable
    if (pool.isEmpty) return null;
    for (var t = 0; t < 20; t++) {
      final head = pool[rng.nextInt(pool.length)];
      if (occupied.contains(head)) continue;
      final lane = space.exitLane(head, dir);
      if (lane.every((p) => !occupied.contains(p))) return head;
    }
    return null;
  }

  /// Vecinos ortogonales dentro del espacio que no están bloqueados (ni fuera
  /// de [allowedBody], si se confina el cuerpo a una región — #68). Itera
  /// [BoardSpace.directions] en vez de chequear bounds a mano: mismo orden
  /// (up, down, left, right — ver Direction) que la versión anterior, así que
  /// la secuencia de `rng.nextInt(options.length)` no cambia (ADR-0005).
  List<Position> _freeNeighbors(
      Position p, BoardSpace space, Set<Position> blocked,
      {Set<Position>? allowedBody}) {
    final result = <Position>[];
    for (final dir in space.directions) {
      final next = space.step(p, dir);
      if (next == null) continue;
      if (blocked.contains(next)) continue;
      if (allowedBody != null && !allowedBody.contains(next)) continue;
      result.add(next);
    }
    return result;
  }
}
```

- [ ] **Step 2: Run the generator's own test suite**

Run: `flutter test test/infrastructure/generators/graph_board_generator_test.dart test/infrastructure/generators/graph_board_generator_perf_test.dart test/infrastructure/generators/graph_board_themed_test.dart`
Expected: all passing, including the same-seed determinism tests and the 50×50 perf/determinism test — these compare two in-process generations to each other and must still agree.

- [ ] **Step 3: Run the golden boards regression test — this is the critical gate**

Run: `flutter test test/tool/level_production/golden_boards_regression_test.dart`
Expected: 2/2 passing, byte-identical to the pre-refactor fixture captured in Task 1. **If this fails, do not touch the fixture — the refactor introduced a reproducibility bug; find and fix it** (most likely cause: an extra/missing/reordered `rng.nextInt` call, or a candidate-ordering change in `_freeNeighbors`).

- [ ] **Step 4: Run the full suite**

Run: `flutter test` — expect all passing (no other file was touched by this task).

- [ ] **Step 5: Update `AI_HISTORY.MD` (Entrada 082, "front#73 (fragmento 5) — Generador migrado a BoardSpace, golden boards verdes") and commit together with the code**

```bash
git add AI_HISTORY.MD lib/infrastructure/generators/graph_board_generator.dart
git commit -m "$(cat <<'EOF'
refactor(infrastructure): generator uses BoardSpace, removes _lane clone

Replaces the private _lane exit-path clone and _freeNeighbors' manual
bounds checks with space.exitLane/space.step (ADR-0005). RNG call order
and candidate ordering are unchanged (Direction.values order matches
the prior up/down/left/right bounds-check order exactly) — verified
against the golden boards fixture from front#73 fragment 1.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Presentation — one projection helper

**Files:**
- Create: `lib/presentation/game/direction_projection.dart`
- Modify: `lib/presentation/game/painters/arrow_painter.dart`
- Modify: `lib/presentation/game/painters/snake_exit_painter.dart`
- Modify: `lib/presentation/game/widgets/arrow_widget.dart`

**Interfaces:**
- Consumes: `Direction`, `Position` (domain value objects — presentation is explicitly allowed to depend on these primitives, never on `BoardSpace`).
- Produces: `Offset directionUnit(Direction dir)`, `double directionAngle(Direction dir)`, `int cellsToEdge(Position head, Direction dir, {required int cols, required int rows})`.

**Non-negotiable:** painters/widgets must keep receiving primitives (`cols`, `rows`, `Position`, `Direction`) — do not thread a `BoardSpace` into any presentation file. `directionAngle` reproduces `arrow_painter`'s current literal values (`0.0`, `math.pi`, `math.pi/2`, `-math.pi/2`) exactly — do not derive it via `atan2` from `directionUnit`, even though that would be mathematically equivalent: a literal switch guarantees bit-identical doubles, avoiding any floating-point risk to the pixel-identical-output requirement.

- [ ] **Step 1: Write the consolidated helper**

```dart
// lib/presentation/game/direction_projection.dart
import 'dart:math' as math;
import 'dart:ui';

import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

/// Consolida la proyección dirección→pantalla que antes vivía duplicada en
/// ArrowPainter, SnakeExitPainter y ArrowWidget (ADR-0005 D4). Los
/// painters/widgets siguen recibiendo primitivas (cols/rows/Position),
/// nunca un BoardSpace: la proyección de render es un seam distinto del
/// dominio.

/// Vector unitario de [dir] en coordenadas de pantalla (x=col, y=row).
Offset directionUnit(Direction dir) => switch (dir) {
      Direction.right => const Offset(1, 0),
      Direction.left => const Offset(-1, 0),
      Direction.down => const Offset(0, 1),
      Direction.up => const Offset(0, -1),
    };

/// Ángulo en radianes de [dir], para rotar la cabeza de la flecha dibujada.
double directionAngle(Direction dir) => switch (dir) {
      Direction.right => 0.0,
      Direction.left => math.pi,
      Direction.down => math.pi / 2,
      Direction.up => -math.pi / 2,
    };

/// Distancia en celdas desde [head] hasta la frontera del tablero cols×rows
/// siguiendo [dir]. Aritmética de presentación legítimamente 2D (ADR-0005
/// D4: "painters siguen recibiendo primitivas") — equivalente numérico a
/// `RectSpace(cols, rows).exitLane(head, dir).length`.
int cellsToEdge(Position head, Direction dir,
        {required int cols, required int rows}) =>
    switch (dir) {
      Direction.right => cols - 1 - head.col,
      Direction.left => head.col,
      Direction.down => rows - 1 - head.row,
      Direction.up => head.row,
    };
```

- [ ] **Step 2: Wire `arrow_painter.dart`**

Add `import '../direction_projection.dart';`. Change:
```dart
  void _drawHead(Canvas canvas, double stroke) {
    final tip = _center(cells.last);
    final angle = switch (headDirection) {
      Direction.right => 0.0,
      Direction.left => math.pi,
      Direction.down => math.pi / 2,
      Direction.up => -math.pi / 2,
    };
```
to:
```dart
  void _drawHead(Canvas canvas, double stroke) {
    final tip = _center(cells.last);
    final angle = directionAngle(headDirection);
```

- [ ] **Step 3: Wire `snake_exit_painter.dart`**

Add `import '../direction_projection.dart';`. Delete the private `_dirUnit` method entirely:
```dart
  Offset _dirUnit() => switch (headDirection) {
        Direction.up => const Offset(0, -1),
        Direction.down => const Offset(0, 1),
        Direction.left => const Offset(-1, 0),
        Direction.right => const Offset(1, 0),
      };
```
Replace every call site of `_dirUnit()` in this file (inside `paint()` and inside `_drawHead`) with `directionUnit(headDirection)`.

Replace the body of `_laneCells`:
```dart
  int _laneCells() {
    final h = cells.last;
    return switch (headDirection) {
      Direction.right => cols - 1 - h.col,
      Direction.left => h.col,
      Direction.down => rows - 1 - h.row,
      Direction.up => h.row,
    };
  }
```
with:
```dart
  int _laneCells() =>
      cellsToEdge(cells.last, headDirection, cols: cols, rows: rows);
```

- [ ] **Step 4: Wire `arrow_widget.dart`**

Add `import '../direction_projection.dart';`. Delete the private `_dirUnit` method entirely:
```dart
  (double, double) _dirUnit() => switch (widget.arrow.direction) {
        Direction.up => (0, -1),
        Direction.down => (0, 1),
        Direction.left => (-1, 0),
        Direction.right => (1, 0),
      };
```
Change its call site from:
```dart
          final t = _shake.value;
          final magnitude = math.sin(t * math.pi * 4) * (1 - t) * 7;
          final (ux, uy) = _dirUnit();
          return Transform.translate(
            offset: Offset(ux * magnitude, uy * magnitude),
            child: child,
          );
```
to:
```dart
          final t = _shake.value;
          final magnitude = math.sin(t * math.pi * 4) * (1 - t) * 7;
          final unit = directionUnit(widget.arrow.direction);
          return Transform.translate(
            offset: Offset(unit.dx * magnitude, unit.dy * magnitude),
            child: child,
          );
```

- [ ] **Step 5: Clean up now-unused imports**

Run `flutter analyze`. If `Direction` (or `dart:math`) is flagged unused in any of the three edited files because its only remaining reference was the deleted switch, remove that specific unused import — but check first: `Direction` is very likely still used as a field/parameter type elsewhere in each file (e.g. `headDirection` itself), so don't remove it reflexively.

- [ ] **Step 6: Run presentation tests — must pass with zero changes to the test files themselves**

Run: `flutter test test/presentation/game/painters/arrow_painter_test.dart test/presentation/game/painters/snake_exit_painter_test.dart test/presentation/game/widgets/arrow_widget_test.dart test/presentation/game/widgets/board_widget_test.dart`
Expected: all passing, unmodified. `arrow_painter_test.dart` contains an analytical test hardcoding the same angle constants (`-math.pi/2`, `math.pi/2`, `0.0`, `math.pi`) this task's `directionAngle` also uses literally — if you find yourself wanting to "fix" that test, stop: it should already pass unchanged, since `directionAngle`'s values are byte-identical to what it replaced.

- [ ] **Step 7: Run the full suite**

Run: `flutter test` — expect all passing.

- [ ] **Step 8: Update `AI_HISTORY.MD` (Entrada 083, "front#73 (fragmento 6) — Helper de proyección de presentación") and commit together with the code**

```bash
git add AI_HISTORY.MD lib/presentation/game/direction_projection.dart lib/presentation/game/painters/arrow_painter.dart lib/presentation/game/painters/snake_exit_painter.dart lib/presentation/game/widgets/arrow_widget.dart
git commit -m "$(cat <<'EOF'
refactor(presentation): consolidate direction projection into one helper

arrow_painter, snake_exit_painter, and arrow_widget each reimplemented
direction->screen-vector arithmetic (ADR-0005 D4). Collapses all of it
into direction_projection.dart; painters/widgets still receive only
primitives (cols/rows/Position/Direction), never a BoardSpace. Visual
output is pixel-identical — existing tests pass unmodified.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: OCP certification — `ArrowBoard` over `HoledRectSpace`, zero consumer edits

**Files:**
- Create: `test/domain/entities/arrow_board_holed_space_certification_test.dart`

**Interfaces:**
- Consumes: `ArrowBoard`, `Arrow` (Task 4), `HoledRectSpace` (Task 3) — no production code is touched by this task; if it needs to be, something upstream is wrong.

- [ ] **Step 1: Write the certification test**

```dart
// test/domain/entities/arrow_board_holed_space_certification_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import '../../support/holed_rect_space.dart';

/// Certificación OCP (ADR-0005 D2/D7): ArrowBoard funciona sobre un espacio
/// agujereado sin editar una sola línea de Arrow/ArrowBoard. Si este archivo
/// compila y pasa usando solo HoledRectSpace + la API pública existente, la
/// extensibilidad prometida por BoardSpace queda demostrada, no solo
/// documentada.
void main() {
  group('ArrowBoard sobre HoledRectSpace — certificación OCP', () {
    test('una flecha cuyo carril termina en el agujero puede salir', () {
      // Arrange: agujero en (2,4); flecha corta hacia la derecha desde (2,1).
      final space = HoledRectSpace(6, 6, holes: {Position(row: 2, col: 4)});
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 2, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow], space: space);

      // Act & Assert
      expect(board.canExit(arrow.id), isTrue);
    });

    test('una flecha cuyo carril hacia el agujero está bloqueado no puede salir', () {
      // Arrange: misma geometría, pero otra flecha ocupa la celda intermedia.
      final space = HoledRectSpace(6, 6, holes: {Position(row: 2, col: 4)});
      final blocker = Arrow(
        id: ArrowId('blocker'),
        cells: [Position(row: 2, col: 3)],
        headDirection: Direction.down,
      );
      final arrow = Arrow(
        id: ArrowId('a1'),
        cells: [Position(row: 2, col: 1)],
        headDirection: Direction.right,
      );
      final board = ArrowBoard(arrows: [arrow, blocker], space: space);

      // Act & Assert
      expect(board.canExit(arrow.id), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/domain/entities/arrow_board_holed_space_certification_test.dart`
Expected: 2/2 passing.

- [ ] **Step 3: Confirm zero production files changed**

Run: `git status` — only the new test file should be untracked/staged. If this task made you touch `lib/`, stop: the abstraction isn't actually closed for the extension it claims to support, and that's a plan-level problem to raise, not something to patch around here.

- [ ] **Step 4: Update `AI_HISTORY.MD` (Entrada 084, "front#73 (fragmento 7) — Certificación OCP sobre HoledRectSpace") and commit together with the code**

```bash
git add AI_HISTORY.MD test/domain/entities/arrow_board_holed_space_certification_test.dart
git commit -m "$(cat <<'EOF'
test(domain): certify ArrowBoard over HoledRectSpace (OCP, ADR-0005 D7)

Same ArrowBoard/Arrow, zero consumer edits, a holed space instead of a
rectangular one: exit lane ending at a hole exits, blocked lane
doesn't. Proves the BoardSpace seam is real, not just documented.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: README architecture section + final acceptance-criteria verification

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing new — this task verifies the finished state of Tasks 1-7.

- [ ] **Step 1: Update the architecture tree**

In `README.md`, inside the `## Architecture` code fence, change the `game_core/` row (currently):
```
│   ├── game_core/   Position, Direction, MoveCount, Score, Stars
```
to:
```
│   ├── game_core/   Position, Direction, MoveCount, Score, Stars, space/ (BoardSpace, RectSpace)
```

- [ ] **Step 2: Add one sentence introducing `BoardSpace`**

Immediately after the existing paragraph that ends `...every Riverpod provider that constructs a concrete infrastructure/ class lives in presentation/providers/.` (end of the `## Architecture` section, before `## Tooling`), add:

```markdown

`BoardSpace` (`domain/game_core/space/`) concentrates the board's geometry — adjacency, exit lanes, the frontier a snake-arrow exits through — behind `step`/`contains` primitives; `RectSpace` is the only production implementation, and `ArrowBoard` holds a `space: BoardSpace` instead of raw `cols`/`rows` (ADR-0005). A second, test-only implementation (`HoledRectSpace`, holed board) certifies the seam is real: `ArrowBoard.canExit` runs over it with zero consumer changes.
```

- [ ] **Step 3: Run the acceptance-criteria greps**

```bash
grep -rn "Direction\." lib/ --include="*.dart" | grep -v "domain/game_core/value_objects/direction.dart" | grep -v "domain/game_core/space/rect_space.dart" | grep -v "infrastructure/serialization/level_json_decoder.dart" | grep -v "infrastructure/serialization/level_json_encoder.dart" | grep -v "presentation/game/direction_projection.dart"
```
Expected: empty output (or only non-arithmetic references like type annotations `Direction dir` in method signatures — inspect any hit by hand; the requirement is zero *switches/arithmetic*, not zero *mentions* of the type).

```bash
grep -rln "switch" lib/ --include="*.dart" | xargs grep -l "Direction\."
```
Expected: only `lib/domain/game_core/space/rect_space.dart` and `lib/presentation/game/direction_projection.dart`.

- [ ] **Step 4: Run the full verification suite**

Run: `flutter analyze` — expect zero issues.
Run: `flutter test` — expect all tests passing.
Run: `flutter test test/tool/level_production/golden_boards_regression_test.dart` — expect 2/2 passing (final confirmation the whole refactor preserved determinism end to end).

- [ ] **Step 5: Optional smoke test of the production CLI**

```bash
dart run tool/level_production/produce.dart --tier 1 --seeds 101 --out /tmp/front73-smoke
diff /tmp/front73-smoke/cand-t1-s101.json test/fixtures/golden_boards/cand-t1-s101.json
```
Expected: no diff output. This exercises the real CLI entrypoint end-to-end (Isolate.run included), not just the pure `produceCandidate` function the golden test calls directly.

- [ ] **Step 6: Update `AI_HISTORY.MD` (Entrada 085, "front#73 (fragmento 8) — README + verificación final de criterios de aceptación") and commit together with the code**

```bash
git add AI_HISTORY.MD README.md
git commit -m "$(cat <<'EOF'
docs(front): document the BoardSpace module in README architecture

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

## After all tasks: whole-branch review and PR

Once Tasks 1-8 are complete and reviewed (per `superpowers:subagent-driven-development`'s per-task review loop), dispatch the final whole-branch code reviewer, then use `superpowers:finishing-a-development-branch` to open the PR:

- Title referencing `Closes #73`.
- Body ending with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- **Do not merge** — this repo's `main` is protected and the user decides on merge (per `CLAUDE.md` and the original handoff).
- After opening the PR, comment a summary on issue #73 and report back to the user.
