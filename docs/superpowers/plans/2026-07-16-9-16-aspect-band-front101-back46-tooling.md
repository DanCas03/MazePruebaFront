# 9:16 Aspect Band — Shared VO + Generator Clamp (front#101) + Campaign Ramp Reshape tooling (back#46)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce one app-wide portrait aspect band (`AspectBand`), clamp the runtime board generator + its presets to it (front#101), and reshape the campaign level-production ramp to it (front-repo side of back#46 — the `tool/` producer). The back-repo fixtures/seed/leaderboard work is a **separate, dependent plan**: `MazePruebaBack/docs/superpowers/plans/2026-07-16-back46-campaign-9-16-reseed.md`.

**Architecture:** A single pure-Dart value object `AspectBand` in `lib/domain` is the one source of truth for the band. `GeneratorConfig` (runtime) rejects out-of-band configs; the level-production `ramp.dart` (tooling) is re-tuned to in-band dims and its test oracle asserts each step against `AspectBand`. Runtime and tooling keep their **separate** arrow/timer derivations (already duplicated today) — the only thing they now share is `AspectBand`.

**Tech Stack:** Flutter/Dart, Riverpod, `flutter_test`, Dart CLI tooling under `tool/level_production/`.

## Global Constraints

- **Band (2026-07-16 maintainer decision, supersedes the issues' "0.55–0.60"):** target = `9/16 = 0.5625`; inclusive band `minRatio = 0.53`, `maxRatio = 0.68`. Ratio is measured as `cols / rows` with the portrait convention `cols <= rows`.
- **Clean Mobile Architecture:** `domain/` is pure Dart (no Flutter, no external packages beyond `equatable`). `presentation/` consumes only `application/`. `AspectBand` lives in `domain/`.
- **Tests are AAA (Arrange-Act-Assert);** mock external dependencies; every production change ships with its test.
- **Per-fragment discipline (CLAUDE.md):** after each significant fragment, add an `AI_HISTORY.MD` entry, update `README.md` if public behaviour changes, and make one Conventional Commit per fragment. Do not batch fragments into one commit.
- **`MazePruebaFront` and `MazePruebaBack` are separate git repos** → separate branches/PRs. This plan is entirely front-repo work.
- **Repo root for all paths below:** `C:\Users\danie\Documents\code\Proyects\Desarrollo\ArrowMaze\MazePruebaFront`.

## Coordination / Parallelization (read first)

Execution DAG (see the two-worktree note at the end):

```
Track 0  (Task 0.1)  AspectBand VO ── merge to front main ──┐
                                                            │
                    ┌───────────────────────────────────────┤
                    ▼                                        ▼
Track A (front#101)                        Track B1 (back#46 front tooling)
 A.1 band in GeneratorConfig                B1.1 reshape ramp.dart + oracle
 A.2 retune presets                         B1.2 re-run producer + curate 15
 A.3 mirror in state/UI                     B1.3 re-freeze goldens
 A.4 fix collateral tests/callers           B1.4 hand off 15 JSON → back repo ──▶ back plan (Track B2)
```

- **Track 0 is the only serialization point.** `AspectBand` is imported by both `generator_config.dart` (Track A) and `ramp.dart` (Track B1). Land it first (tiny PR), then A and B1 proceed fully in parallel — they touch **disjoint files** (`lib/` runtime vs `tool/` tooling).
- **Track A ∥ Track B1** — no shared files. Run each in its own git worktree.
- **Track B1 → back plan (B2)** — B1.4 produces the 15 curated JSON fixtures that the back plan consumes. The back plan's test-expectation edits need the **derived** arrow counts/timers that only exist after B1.2 runs the producer.

## File Structure

**Created:**
- `lib/domain/arrows/value_objects/aspect_band.dart` — the shared band VO (Track 0).
- `test/domain/arrows/value_objects/aspect_band_test.dart` — its tests (Track 0).
- `test/presentation/generated/size_presets_test.dart` — asserts every preset is in-band (Track A).

**Modified — Track A (runtime, `lib/`):**
- `lib/domain/arrows/value_objects/generator_config.dart` — add aspect check to `create`.
- `lib/presentation/generated/configurator_screen.dart` — retune `_kSizePresets`.
- `lib/application/state/configurator_state.dart` — in-band default + aspect in `isValid`.
- `test/domain/arrows/value_objects/generator_config_test.dart` — new aspect group + rewrite square-dim derivation cases.
- `test/application/use_cases/generate_board_use_case_test.dart` — replace the out-of-band `5×7` config.

**Modified — Track B1 (tooling, `tool/`):**
- `tool/level_production/ramp.dart` — new in-band `rampTable`; import + assert `AspectBand`.
- `test/tool/level_production/ramp_test.dart` — update the dimension oracle.
- `test/tool/level_production/candidate_producer_test.dart` — update T1 dims + T3 timer.
- `test/tool/level_production/golden_boards_regression_test.dart` + `test/fixtures/golden_boards/*.json` — re-freeze goldens for new representative candidates.

---

## Track 0 — Shared band value object

### Task 0.1: `AspectBand` value object

**Files:**
- Create: `lib/domain/arrows/value_objects/aspect_band.dart`
- Test: `test/domain/arrows/value_objects/aspect_band_test.dart`

**Interfaces:**
- Produces: `AspectBand` with `static const double targetRatio (0.5625), minRatio (0.53), maxRatio (0.68)`; `static double ratioOf(int cols, int rows)`; `static bool contains(int cols, int rows)`; `static int snapRowsForCols(int cols)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/arrows/value_objects/aspect_band_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maze_prueba_front/domain/arrows/value_objects/aspect_band.dart';

void main() {
  group('AspectBand', () {
    test('target ratio is 9:16', () {
      expect(AspectBand.targetRatio, closeTo(0.5625, 1e-9));
    });

    test('contains accepts shapes inside the band (inclusive edges)', () {
      expect(AspectBand.contains(9, 16), isTrue);   // 0.5625 target
      expect(AspectBand.contains(6, 10), isTrue);   // 0.600
      expect(AspectBand.contains(12, 22), isTrue);  // 0.545
      expect(AspectBand.contains(53, 100), isTrue); // 0.53 low edge
      expect(AspectBand.contains(68, 100), isTrue); // 0.68 high edge
    });

    test('contains rejects shapes outside the band', () {
      expect(AspectBand.contains(6, 8), isFalse);   // 0.75  > 0.68
      expect(AspectBand.contains(25, 25), isFalse); // 1.0   square
      expect(AspectBand.contains(10, 20), isFalse); // 0.50  < 0.53
    });

    test('snapRowsForCols puts a fixed cols nearest the target and stays in band', () {
      expect(AspectBand.snapRowsForCols(6), 11);    // 6 / 0.5625 = 10.67 -> 11
      expect(AspectBand.contains(6, AspectBand.snapRowsForCols(6)), isTrue);
      expect(AspectBand.contains(9, AspectBand.snapRowsForCols(9)), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/arrows/value_objects/aspect_band_test.dart`
Expected: FAIL — `aspect_band.dart` does not exist (import error).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/domain/arrows/value_objects/aspect_band.dart
/// Single source of truth for the app-wide portrait aspect band.
///
/// A board's shape is measured as `ratio = cols / rows` under the portrait
/// convention `cols <= rows`. Boards must fall inside [minRatio, maxRatio] so
/// they fill a phone screen without large side margins. Target is 9:16.
///
/// Consumed by GeneratorConfig (runtime clamp, front#101) and by the
/// level-production ramp (campaign reshape, back#46) so both agree on one
/// number. Pure Dart — no Flutter, no external packages.
class AspectBand {
  const AspectBand._();

  /// 9:16 portrait target.
  static const double targetRatio = 9 / 16; // 0.5625

  /// Inclusive band bounds (maintainer decision 2026-07-16).
  static const double minRatio = 0.53;
  static const double maxRatio = 0.68;

  /// cols / rows. Caller guarantees rows > 0.
  static double ratioOf(int cols, int rows) => cols / rows;

  /// Whether a cols×rows shape is inside the band (edges inclusive).
  static bool contains(int cols, int rows) {
    final r = ratioOf(cols, rows);
    return r >= minRatio && r <= maxRatio;
  }

  /// Given a fixed [cols], the rows that put the shape nearest the target.
  /// For internally-suggested defaults only — never to silently rewrite
  /// explicit user input (that path rejects instead).
  static int snapRowsForCols(int cols) => (cols / targetRatio).round();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/arrows/value_objects/aspect_band_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Record + commit**

Add an `AI_HISTORY.MD` entry (new fragment: shared aspect band VO). Then:

```bash
git add lib/domain/arrows/value_objects/aspect_band.dart \
        test/domain/arrows/value_objects/aspect_band_test.dart AI_HISTORY.MD
git commit -m "feat(domain): add AspectBand value object (9:16 portrait band)"
```

> **Merge Track 0 to front `main` before starting Track A and Track B1.**

---

## Track A — front#101: clamp the runtime generator + presets

### Task A.1: Reject out-of-band configs in `GeneratorConfig`

**Files:**
- Modify: `lib/domain/arrows/value_objects/generator_config.dart` (factory `create`, ~lines 53-69)
- Test: `test/domain/arrows/value_objects/generator_config_test.dart`

**Interfaces:**
- Consumes: `AspectBand.contains` (Task 0.1); existing `InvalidGeneratorConfigException`.
- Produces: `GeneratorConfig.create` throws `InvalidGeneratorConfigException` when `!AspectBand.contains(cols, rows)`.

- [ ] **Step 1: Write the failing test** — add this group to `generator_config_test.dart`:

```dart
  group('validación de aspecto (AspectBand)', () {
    test('acepta una config dentro de la banda', () {
      expect(() => GeneratorConfig.create(cols: 9, rows: 16), returnsNormally); // 0.5625
      expect(() => GeneratorConfig.create(cols: 6, rows: 10), returnsNormally); // 0.60
    });

    test('rechaza un tablero cuadrado (fuera de banda)', () {
      expect(
        () => GeneratorConfig.create(cols: 25, rows: 25), // 1.0
        throwsA(isA<InvalidGeneratorConfigException>()
            .having((e) => e.message, 'message', contains('aspect'))),
      );
    });

    test('rechaza un portrait demasiado ancho (0.75 > 0.68)', () {
      expect(
        () => GeneratorConfig.create(cols: 6, rows: 8),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });

    test('rechaza un portrait demasiado estrecho (0.50 < 0.53)', () {
      expect(
        () => GeneratorConfig.create(cols: 10, rows: 20),
        throwsA(isA<InvalidGeneratorConfigException>()),
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/arrows/value_objects/generator_config_test.dart --name "validación de aspecto"`
Expected: FAIL — square/out-of-band configs currently succeed.

- [ ] **Step 3: Write minimal implementation** — in `create`, after the two `_requireInRange` calls, add:

```dart
    // front#101: shapes must fall inside the app-wide portrait band so a
    // generated board fills a phone screen. Explicit user input is rejected
    // (defaults are snapped elsewhere via AspectBand.snapRowsForCols).
    if (!AspectBand.contains(cols, rows)) {
      throw InvalidGeneratorConfigException(
        'aspect cols:rows must be within [${AspectBand.minRatio}, '
        '${AspectBand.maxRatio}] (portrait 9:16), got ${cols}x$rows = '
        '${(cols / rows).toStringAsFixed(3)}');
    }
```

Add the import at the top of `generator_config.dart`:

```dart
import 'package:maze_prueba_front/domain/arrows/value_objects/aspect_band.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/arrows/value_objects/generator_config_test.dart --name "validación de aspecto"`
Expected: PASS.

- [ ] **Step 5: Commit** (defer the full-file run to A.4, which fixes the now-broken square-dim cases)

```bash
git add lib/domain/arrows/value_objects/generator_config.dart \
        test/domain/arrows/value_objects/generator_config_test.dart AI_HISTORY.MD
git commit -m "feat(domain): reject out-of-band aspect in GeneratorConfig (front#101)"
```

### Task A.2: Retune the size presets into the band

**Files:**
- Modify: `lib/presentation/generated/configurator_screen.dart` (`_kSizePresets`, ~lines 133-144)
- Test: `test/presentation/generated/size_presets_test.dart` (create)

**Interfaces:**
- Consumes: `AspectBand.contains` (Task 0.1).
- Produces: a `List<_Preset>` where every entry is in-band and `cols < rows`.

> The presets are a private const inside the screen file. To make them testable without importing Flutter widget internals, **extract** the preset list into a small library file, then re-export from the screen.

- [ ] **Step 1: Create the preset source of truth**

Create `lib/presentation/generated/size_presets.dart`:

```dart
/// Portrait size presets for the procedural generator configurator.
/// Every entry is inside AspectBand (front#101); the shapes span small→large.
typedef SizePreset = ({String label, int cols, int rows});

const List<SizePreset> kSizePresets = [
  (label: 'S',  cols: 6,  rows: 10), // 0.600
  (label: 'M',  cols: 9,  rows: 16), // 0.5625 (target)
  (label: 'L',  cols: 14, rows: 25), // 0.560
  (label: 'XL', cols: 19, rows: 34), // 0.559
];
```

- [ ] **Step 2: Write the failing test**

```dart
// test/presentation/generated/size_presets_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maze_prueba_front/domain/arrows/value_objects/aspect_band.dart';
import 'package:maze_prueba_front/domain/arrows/value_objects/generator_config.dart';
import 'package:maze_prueba_front/presentation/generated/size_presets.dart';

void main() {
  group('kSizePresets', () {
    test('every preset is inside the aspect band', () {
      for (final p in kSizePresets) {
        expect(AspectBand.contains(p.cols, p.rows), isTrue,
            reason: '${p.label} ${p.cols}x${p.rows} out of band');
      }
    });

    test('every preset is a portrait shape within dimension bounds', () {
      for (final p in kSizePresets) {
        expect(p.cols, lessThan(p.rows));
        expect(p.cols, greaterThanOrEqualTo(GeneratorConfig.minDimension));
        expect(p.rows, lessThanOrEqualTo(GeneratorConfig.maxDimension));
      }
    });

    test('every preset builds a valid GeneratorConfig', () {
      for (final p in kSizePresets) {
        expect(() => GeneratorConfig.create(cols: p.cols, rows: p.rows),
            returnsNormally);
      }
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/presentation/generated/size_presets_test.dart`
Expected: FAIL — `size_presets.dart` not yet imported by the screen / list still square.

- [ ] **Step 4: Point the screen at the shared list**

In `lib/presentation/generated/configurator_screen.dart`, delete the inline `_kSizePresets`/`_Preset` definitions and instead:

```dart
import 'package:maze_prueba_front/presentation/generated/size_presets.dart';
```

Replace all references to `_kSizePresets` with `kSizePresets` and `_Preset` with `SizePreset` in that file.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/presentation/generated/size_presets_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/generated/size_presets.dart \
        lib/presentation/generated/configurator_screen.dart \
        test/presentation/generated/size_presets_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): retune generator size presets into the band (front#101)"
```

### Task A.3: In-band default + aspect in configurator `isValid`

**Files:**
- Modify: `lib/application/state/configurator_state.dart` (default dims ~23-29; `isValid` ~38-43)

**Interfaces:**
- Consumes: `AspectBand.contains`.
- Produces: `ConfiguratorState.isValid` returns false when the current cols×rows is out of band; the default state is in-band.

- [ ] **Step 1: Write the failing test** — add to (or create) `test/application/state/configurator_state_test.dart`:

```dart
  test('default configurator state is inside the aspect band', () {
    const s = ConfiguratorState(); // or the class's documented default ctor
    expect(AspectBand.contains(s.cols, s.rows), isTrue);
  });

  test('isValid is false when the current shape is out of band', () {
    final s = const ConfiguratorState().copyWith(cols: 6, rows: 8); // 0.75
    expect(s.isValid, isFalse);
  });
```

(Import `AspectBand` and the state class.)

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/application/state/configurator_state_test.dart`
Expected: FAIL — default is `6×8` (0.75, out of band) and `isValid` ignores aspect.

- [ ] **Step 3: Implement**

- Change the default dims to the S preset (`cols: 6, rows: 10`).
- In `isValid`, add `&& AspectBand.contains(cols, rows)` to the existing seed + dimension-bound checks. Import `AspectBand`.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/application/state/configurator_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Regenerate + commit**

If `configurator_state.dart`/its controller are `@riverpod`/codegen-backed, run `dart run build_runner build --delete-conflicting-outputs` first. Then:

```bash
git add lib/application/state/configurator_state.dart \
        test/application/state/configurator_state_test.dart AI_HISTORY.MD
git commit -m "feat(application): couple configurator validity to the aspect band (front#101)"
```

### Task A.4: Fix collateral out-of-band constructions + full suite green

**Files:**
- Modify: `test/domain/arrows/value_objects/generator_config_test.dart` (derivation groups)
- Modify: `test/application/use_cases/generate_board_use_case_test.dart` (the `5×7` config)

**Context:** the band now rejects the square/wide dims that several existing tests used. Replace them with in-band dims and recomputed expectations. All derived numbers below were computed from the existing formulae:
`arrowCount = (cols*rows*fillRatio / avgPathLen).round().clamp(4, cols*rows~/2)`, `avgPathLen = (2 + maxPathLen)/2`; `timeLimitSec = (cols*rows*secondsPerCell).round().clamp(30, 300)`. Difficulty: easy `(0.40, 3, 3.0)`, medium `(0.55, 6, 2.0)`, hard `(0.70, 9, 1.5)`.

- [ ] **Step 1: Rewrite the "derivación por preset" cases** in `generator_config_test.dart` to in-band dims:

```dart
    // easy 6×10 (60 cells): 60*0.40/2.5 = 9.6 -> 10
    expect(GeneratorConfig.create(cols: 6, rows: 10, difficulty: Difficulty.easy).arrowCount, 10);
    // medium 9×16 (144): 144*0.55/4 = 19.8 -> 20
    expect(GeneratorConfig.create(cols: 9, rows: 16, difficulty: Difficulty.medium).arrowCount, 20);
    // hard 6×10 (60): 60*0.70/5.5 = 7.63 -> 8
    expect(GeneratorConfig.create(cols: 6, rows: 10, difficulty: Difficulty.hard).arrowCount, 8);
    // hard 4×7 (28): 28*0.70/5.5 = 3.56 -> 4 (clamped to minArrowCount)
    expect(GeneratorConfig.create(cols: 4, rows: 7, difficulty: Difficulty.hard).arrowCount, 4);
```

- [ ] **Step 2: Rewrite the "derivación del timer" cases** in `generator_config_test.dart`:

```dart
    // untimed -> null
    expect(GeneratorConfig.create(cols: 6, rows: 10).timeLimitSec, isNull);
    // easy 6×10 timed: 60*3.0 = 180
    expect(GeneratorConfig.create(cols: 6, rows: 10, difficulty: Difficulty.easy, timed: true).timeLimitSec, 180);
    // medium 9×16 timed: 144*2.0 = 288
    expect(GeneratorConfig.create(cols: 9, rows: 16, difficulty: Difficulty.medium, timed: true).timeLimitSec, 288);
    // hard 6×10 timed: 60*1.5 = 90
    expect(GeneratorConfig.create(cols: 6, rows: 10, difficulty: Difficulty.hard, timed: true).timeLimitSec, 90);
    // ceiling clamp: medium 19×34 timed: 646*2.0 = 1292 -> 300
    expect(GeneratorConfig.create(cols: 19, rows: 34, difficulty: Difficulty.medium, timed: true).timeLimitSec, 300);
```

> Note: the sub-30 floor branch is no longer reachable with an in-band board (smallest in-band ≈ 4×7 = 28 cells). Drop the old floor assertion; leave a `// floor unreachable in-band` comment. Also update any dims in the "seed y semántica de valor" group from `6×8` to `6×10`.

- [ ] **Step 3: Fix `generate_board_use_case_test.dart`**

Open the file; the config at ~line 85 is `5×7` (0.714, now out of band). Replace with `6×10` medium and update the expected arrow count to `8` (`60*0.55/4 = 8.25 -> 8`). Update the comment accordingly.

- [ ] **Step 4: Sweep for any other out-of-band constructions**

Run: `grep -rn "GeneratorConfig.create\|GeneratorConfig(" lib test`
For each call site with square/out-of-band literal dims, switch to an in-band shape (or the S preset). Runtime call sites that pass user/preset dims are already safe.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS — entire suite green (0 failures).

- [ ] **Step 6: Update README + commit**

Update `README.md` where it documents the generator/configurator sizing to state the 9:16 band constraint. Then:

```bash
git add test/domain/arrows/value_objects/generator_config_test.dart \
        test/application/use_cases/generate_board_use_case_test.dart \
        README.md AI_HISTORY.MD
git commit -m "test(front): move generator tests to in-band dims; document 9:16 band (front#101)"
```

**Track A acceptance check (front#101):** out-of-band (25×25) rejected ✓; every preset in-band ✓; arrow/timer derivations re-checked for new shapes ✓; unit tests cover in-band-ok / out-of-band-rejected / each-preset-in-band ✓.

---

## Track B1 — back#46 (front-repo side): reshape the campaign ramp

### Task B1.1: Re-tune `ramp.dart` to in-band dims + assert against `AspectBand`

**Files:**
- Modify: `tool/level_production/ramp.dart` (`rampTable` ~81-94; add import + assertion)
- Test: `test/tool/level_production/ramp_test.dart` (the dimension oracle, ~7-78)

**Interfaces:**
- Consumes: `AspectBand.contains` (Task 0.1).
- Produces: a `rampTable` whose every step is in-band; `RampStep.arrowCount` / `timeLimitSec` re-derived from the new dims.

New ramp (ratios all in `[0.53, 0.68]`; `cols <= rows`; keeps 5 tiers + finale = 15 levels). fillRatio/maxPathLen kept from the current ramp so difficulty progression stays sensible; the derived arrow/timer numbers below follow from the tooling's own formula (`avgPathLen = (2+maxPathLen)/2`; `timeLimitSec = ceil(arrowCount*4 / 30)*30`, `null` when untimed):

| tier | finale | cols×rows | ratio | fillRatio | maxPathLen | timed | arrowCount | timeLimitSec |
|---|---|---|---|---|---|---|---|---|
| 1 | false | 6×10  | 0.600 | 0.30 | 3  | false | 7   | – |
| 2 | false | 9×16  | 0.5625| 0.38 | 5  | false | 16  | – |
| 3 | false | 12×22 | 0.545 | 0.45 | 7  | true  | 26  | 120 |
| 4 | false | 19×34 | 0.559 | 0.55 | 10 | true  | 59  | 240 |
| 5 | false | 25×44 | 0.568 | 0.60 | 12 | true  | 94  | 390 |
| 5 | true  | 28×50 | 0.560 | 0.65 | 12 | true  | 130 | 540 |

> Arrow-count check (executor should confirm after edit): T1 `60*0.30/2.5=7.2→7`; T2 `144*0.38/3.5=15.6→16`; T3 `264*0.45/4.5=26.4→26`; T4 `646*0.55/6=59.2→59`; T5 `1100*0.60/7=94.3→94`; finale `1400*0.65/7=130`. Progression `7→16→26→59→94→130` is monotonic. If any tier's density looks off after seeing real boards in B1.2, nudge `fillRatio` and re-derive.

- [ ] **Step 1: Update the oracle test first** — in `ramp_test.dart`, replace the exact per-step tuples and derived expectations with the table above, and **add** an `AspectBand` guard:

```dart
import 'package:maze_prueba_front/domain/arrows/value_objects/aspect_band.dart';
// ...
test('every ramp step is inside the aspect band', () {
  for (final step in rampTable) {
    expect(AspectBand.contains(step.cols, step.rows), isTrue,
        reason: 'tier ${step.tier} ${step.cols}x${step.rows} out of band');
  }
});
```

Update: the exact tuples (`(6,10,0.30,3) (9,16,0.38,5) (12,22,0.45,7) (19,34,0.55,10) (25,44,0.60,12)` + finale `(28,50,0.65,12)`); the `cols <= rows` assertions (still hold); the `arrowCount` expectations to `7,16,26,59,94,130`; the `timeLimitSec` expectations to `120,240,390,540` (all `% 30 == 0`); timed flags (tiers 1-2 false, 3-5 + finale true).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/tool/level_production/ramp_test.dart`
Expected: FAIL — current ramp still `6×8 … 50×50`.

- [ ] **Step 3: Edit `ramp.dart`** — replace the six `const RampStep(...)` rows with the new dims/fillRatio/maxPathLen/timed, and add near the top:

```dart
import 'package:maze_prueba_front/domain/arrows/value_objects/aspect_band.dart';
```

Add an assertion inside `rampStepFor` (or a `RampStep` assert) so an out-of-band ramp can never ship:

```dart
assert(AspectBand.contains(step.cols, step.rows),
    'ramp step ${step.cols}x${step.rows} out of aspect band');
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/tool/level_production/ramp_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tool/level_production/ramp.dart test/tool/level_production/ramp_test.dart AI_HISTORY.MD
git commit -m "feat(tool): reshape campaign ramp to 9:16 aspect band (back#46)"
```

### Task B1.2: Re-run the producer and curate the 15 levels

**Files:** produces JSON under `out/candidates/` (git-ignored working output) + batch manifests.

- [ ] **Step 1: Generate candidates per tier** (widen `--seeds` to get enough solvable, fully-placed candidates to choose from):

```bash
dart run tool/level_production/produce.dart --tier 1 --seeds 100..130
dart run tool/level_production/produce.dart --tier 2 --seeds 100..130
dart run tool/level_production/produce.dart --tier 3 --seeds 100..140
dart run tool/level_production/produce.dart --tier 4 --seeds 100..160 --budget 15
dart run tool/level_production/produce.dart --tier 5 --seeds 900..960 --budget 20
dart run tool/level_production/produce.dart --tier 5 --finale --seeds 900..960 --budget 30
```

- [ ] **Step 2: Curate 3 per tier → 15** (the manual selection rule): from each tier's `manifest-*.md`, pick 3 candidates that (a) placed == requested arrows, (b) passed validation (no `errors-*.md` entry), (c) give a smooth in-tier difficulty spread. For tier 5 pick 2 regular + the finale = the last 3.

- [ ] **Step 3: Assign final order + ids** — rename/copy the 15 chosen `cand-tN-sNNN.json` to `level-01.json … level-15.json`, setting `levelId`/`order` to 1..15 in tier order (T1→1,2,3 … finale→15). Record each `level → cand-tN-sNNN` mapping for the provenance manifest.

- [ ] **Step 4: Sanity-check the shapes**

Run a quick check that all 15 chosen boards are in-band and monotonic in size (executor may script this with a small Dart snippet or eyeball the manifest rows). No commit yet — these JSONs are handed to the back plan in B1.4.

### Task B1.3: Re-freeze the tooling goldens

**Files:**
- Modify: `test/tool/level_production/candidate_producer_test.dart` (T1 dims + T3 timer)
- Modify: `test/tool/level_production/golden_boards_regression_test.dart` + `test/fixtures/golden_boards/*.json`

- [ ] **Step 1: Update `candidate_producer_test.dart`** — change the T1 assertion from `cols==6, rows==8` to `cols==6, rows==10`; change the T3 derived `timeLimitSec` from `150` to `120`. Keep the id-format / determinism / overlap-empty checks.

- [ ] **Step 2: Re-capture the golden boards** — the old goldens (`cand-t1-s101` 6×8, `cand-t5-s918` 50×50) no longer exist. Pick two representative NEW candidate ids (one small tier-1, one finale) from B1.2's output, regenerate them deterministically, and overwrite the corresponding `test/fixtures/golden_boards/*.json` with the new byte-exact output. Update the ids referenced in `golden_boards_regression_test.dart`.

- [ ] **Step 3: Run the tooling test suite**

Run: `flutter test test/tool/level_production/`
Expected: PASS (ramp + candidate_producer + golden regression + themed unaffected).

- [ ] **Step 4: Commit**

```bash
git add test/tool/level_production/candidate_producer_test.dart \
        test/tool/level_production/golden_boards_regression_test.dart \
        test/fixtures/golden_boards/ AI_HISTORY.MD
git commit -m "test(tool): re-freeze producer goldens for 9:16 ramp (back#46)"
```

### Task B1.4: Hand off the 15 curated fixtures to the back repo

- [ ] **Step 1:** Copy the 15 wire-strict `level-01.json … level-15.json` from B1.2 into `MazePruebaBack/prisma/levels/` (the encoder output is copy-as-is; do not hand-edit fields).
- [ ] **Step 2:** Record the `level → cand-tN-sNNN → dims → arrows → timeLimitSec` mapping and pass it, plus the final table from B1.1, to the back plan (`MazePruebaBack/docs/superpowers/plans/2026-07-16-back46-campaign-9-16-reseed.md`). The back plan's Track B2 continues from here.

**Track B1 acceptance handoff:** ramp in-band + oracle green ✓; 15 curated in-band fixtures produced ✓; tooling goldens re-frozen ✓; fixtures + provenance handed to the back plan.

---

## Self-Review

- **Spec coverage (front#101):** aspect rejection (A.1), in-band presets (A.2), default+isValid (A.3), derivations re-checked + tests (A.4). ✓
- **Spec coverage (back#46 front side):** ramp reshape (B1.1), producer re-run + curation (B1.2), golden re-freeze (B1.3), back handoff (B1.4). ✓ Back-repo fixtures/seed/leaderboard covered by the separate back plan.
- **Type consistency:** `AspectBand.contains/ratioOf/snapRowsForCols/targetRatio/minRatio/maxRatio` used identically across Tasks 0.1, A.1-A.3, B1.1. Presets: `SizePreset`/`kSizePresets` (public, in `size_presets.dart`) referenced by A.2 test + screen.
- **Band number is defined once** (Task 0.1) and only referenced elsewhere — no duplicated literal `0.53/0.68` in `lib/` runtime or `tool/`. (The back repo, being TypeScript, restates the number as a documented test constant — see the back plan.)

## Two-worktree execution note

After Track 0 merges to front `main`, run Track A and Track B1 in parallel isolated worktrees (per superpowers:using-git-worktrees), e.g. `front-101-generator-clamp` and `back46-front-tooling`. They share no files, so no rebase conflicts. Track B1's B1.4 output then unblocks the back plan.
