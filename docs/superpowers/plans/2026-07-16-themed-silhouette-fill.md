# Themed Silhouette Fill — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paint every themed figure cell in its region color (tinted, under the arrows) so themed levels render with no visible holes, by serializing an opaque `silhouette` field (role → region cells) on the level wire.

**Architecture:** Additive, opaque wire field mirroring `palette`. Tooling emits it from the mask; the back seeds/validates it; the client parses it into `Level`, threads it through `GamePlaying`, and a dedicated `SilhouettePainter` paints those cells between the board surface and the arrows. Solvability, `_mountedBoard` (stays full `RectSpace`), and arrow mechanics are untouched — silhouette is paint-only.

**Tech Stack:** Dart/Flutter (front, `flutter_test`), NestJS/TypeScript + Prisma (back, Jest).

## Global Constraints
- Wire field name: `silhouette`. Shape: `{ "<role>": [[row, col], ...] }`. Opaque; absent ⇒ campaign level unchanged.
- Silhouette roles MUST be a subset of `palette` roles; every cell in-bounds (`0 <= row < rows`, `0 <= col < cols`).
- Domain type: `Map<String, List<Position>>?` (list preserves order → golden encode∘decode).
- Silhouette tint alpha default: `0.30`.
- Batch params for regenerating themed fixtures (unchanged from front#68): `--coverage 0.9 --seeds 0..150 --maxlen 8`.
- Front branch `feat/#114-themed-silhouette-fill` (stacked on `feat/#112`). Back branch `feat/#50-themed-silhouette-wire`.
- Conventional Commits; commit trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`. Do NOT merge PRs.
- Register an `AI_HISTORY.MD` entry per fragment in each repo.

---

## File Structure

**Front (`MazePruebaFront/`)**
- `lib/domain/board/entities/level.dart` — +`silhouette` field.
- `lib/infrastructure/serialization/level_json_encoder.dart` — emit `silhouette`.
- `lib/infrastructure/serialization/level_json_decoder.dart` — parse `silhouette` (strict).
- `tool/level_production/themed_producer.dart` — build `silhouette` from `mask.regions`, pass to encoder.
- `lib/application/state/game_state.dart` — `GamePlaying` exposes `silhouette`.
- `lib/application/state/game_controller.dart` — populate `GamePlaying.silhouette` from `level.silhouette`.
- `lib/presentation/game/painters/silhouette_painter.dart` — NEW, paints region cells tinted.
- `lib/presentation/game/widgets/board_widget.dart` — insert silhouette layer under arrows.
- Regenerated: `tool/level_production/themed/themed-{heart,happy_face,bunny}.json` + previews + manifest.

**Back (`MazePruebaBack/`)**
- `prisma/seed.ts` — `LevelFixture` +`silhouette?`; `toData` hoists it.
- `src/infrastructure/database/level-paint.validator.ts` — validate silhouette.
- `prisma/levels/t-{heart,happy-face,bunny}.json` — regenerated with `silhouette`.
- `prisma/levels/manifest.md` — note.
- `CONTEXT.md` + `docs/adr/` new ADR — revise "mask does not travel on the wire".

---

## Task 1 (front): `Level.silhouette` field

**Files:**
- Modify: `lib/domain/board/entities/level.dart`
- Test: `test/domain/board/entities/level_test.dart` (add case; create if absent)

**Interfaces:**
- Produces: `Level({..., Map<String, List<Position>>? silhouette})`, getter `Level.silhouette`.

- [ ] **Step 1: Write failing test**

```dart
// test/domain/board/entities/level_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  Level buildWithSilhouette(Map<String, List<Position>>? s) => Level(
        id: LevelId('t-x'),
        board: ArrowBoard(
          arrows: [
            Arrow(
              id: ArrowId('a0'),
              headDirection: Direction.right,
              cells: const [Position(row: 0, col: 0), Position(row: 0, col: 1)],
              paintRole: 'heart',
            ),
          ],
          space: RectSpace(4, 4),
        ),
        palette: const {'heart': '#FF4D6D'},
        silhouette: s,
      );

  test('stores silhouette when provided and defaults to null', () {
    // Arrange / Act
    final withS = buildWithSilhouette({
      'heart': const [Position(row: 0, col: 0), Position(row: 0, col: 1)],
    });
    final withoutS = buildWithSilhouette(null);
    // Assert
    expect(withS.silhouette!['heart'], hasLength(2));
    expect(withoutS.silhouette, isNull);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`silhouette` param undefined)

Run (from `MazePruebaFront/`, with `export PATH="/opt/homebrew/bin:$PATH"`):
`flutter test test/domain/board/entities/level_test.dart`
Expected: compile error / FAIL.

- [ ] **Step 3: Implement**

In `level.dart`, add the field after `palette` (line 23), the constructor param, and `props`:

```dart
  /// Silueta de figura (front#114): rol→celdas de su región de máscara. Dato
  /// OPACO como [palette] — solo pintura, no afecta solubilidad ni mecánica.
  /// Nulo en campaña. Lo consume el SilhouettePainter para rellenar la figura.
  final Map<String, List<Position>>? silhouette;
```
Add `this.silhouette,` to the constructor params; add `silhouette` to `props`. Add `import '../../game_core/value_objects/position.dart';`.

- [ ] **Step 4: Run — expect PASS**

`flutter test test/domain/board/entities/level_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/domain/board/entities/level.dart test/domain/board/entities/level_test.dart
git commit -m "feat(front/domain): add opaque silhouette field to Level

Refs #114

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 (front): Encoder emits `silhouette`

**Files:**
- Modify: `lib/infrastructure/serialization/level_json_encoder.dart`
- Test: `test/infrastructure/serialization/level_json_encoder_test.dart` (add case)

**Interfaces:**
- Consumes: `Position`.
- Produces: `LevelJsonEncoder.toMap({..., Map<String, List<Position>>? silhouette})` and same param on `encode`. Emits key `silhouette` after `palette` only when non-null.

- [ ] **Step 1: Write failing test**

```dart
test('emits silhouette after palette when provided', () {
  final board = ArrowBoard(
    arrows: [
      Arrow(id: ArrowId('a0'), headDirection: Direction.right,
        cells: const [Position(row: 0, col: 0), Position(row: 0, col: 1)],
        paintRole: 'heart'),
    ],
    space: RectSpace(4, 4),
  );
  final map = const LevelJsonEncoder().toMap(
    levelId: 't-x', board: board,
    palette: const {'heart': '#FF4D6D'},
    silhouette: const {
      'heart': [Position(row: 0, col: 0), Position(row: 0, col: 1), Position(row: 1, col: 0)],
    },
  );
  expect(map['silhouette'], {
    'heart': [[0, 0], [0, 1], [1, 0]],
  });
  // campaign (no silhouette) omits the key
  final campaign = const LevelJsonEncoder().toMap(levelId: 'l1', board: board);
  expect(campaign.containsKey('silhouette'), isFalse);
});
```

- [ ] **Step 2: Run — expect FAIL**

`flutter test test/infrastructure/serialization/level_json_encoder_test.dart`

- [ ] **Step 3: Implement**

Add param `Map<String, List<Position>>? silhouette` to both `toMap` and `encode`. In `toMap`, after the `if (palette != null) 'palette': palette,` line add:

```dart
        if (silhouette != null)
          'silhouette': {
            for (final entry in silhouette.entries)
              entry.key: [for (final c in entry.value) [c.row, c.col]],
          },
```
Thread `silhouette: silhouette` through `encode`'s call to `toMap`. Add `import '../../domain/game_core/value_objects/position.dart';`.

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/serialization/level_json_encoder.dart test/infrastructure/serialization/level_json_encoder_test.dart
git commit -m "feat(front/serialization): encode optional silhouette field

Refs #114

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 (front): Decoder parses `silhouette` (strict) + round-trip

**Files:**
- Modify: `lib/infrastructure/serialization/level_json_decoder.dart`
- Test: `test/infrastructure/serialization/level_json_decoder_test.dart` (add cases)

**Interfaces:**
- Consumes: encoder output shape from Task 2, `Level.silhouette` from Task 1.
- Produces: decoder reads `silhouette` into `Map<String, List<Position>>?`; golden property `encode(decode(x)) == x` holds for themed JSON with silhouette.

- [ ] **Step 1: Write failing tests**

```dart
test('parses silhouette into Level', () {
  final level = const LevelJsonDecoder().decode({
    'levelId': 't-x', 'cols': 4, 'rows': 4,
    'arrows': [
      {'id': 'a0', 'headDir': 'right', 'cells': [[0, 0], [0, 1]], 'paintRole': 'heart'},
    ],
    'palette': {'heart': '#FF4D6D'},
    'silhouette': {'heart': [[0, 0], [0, 1], [1, 0]]},
  });
  expect(level.silhouette!['heart'], const [
    Position(row: 0, col: 0), Position(row: 0, col: 1), Position(row: 1, col: 0),
  ]);
});

test('rejects malformed silhouette', () {
  expect(() => const LevelJsonDecoder().decode({
    'levelId': 't-x', 'cols': 4, 'rows': 4,
    'arrows': [{'id': 'a0', 'headDir': 'right', 'cells': [[0, 0], [0, 1]]}],
    'silhouette': {'heart': [[0]]}, // not a [row,col] pair
  }), throwsA(isA<FormatException>()));
});

test('golden: encode(decode(themed)) reproduces the map', () {
  final json = {
    'levelId': 't-x', 'cols': 4, 'rows': 4,
    'arrows': [
      {'id': 'a0', 'headDir': 'right', 'cells': [[0, 0], [0, 1]], 'paintRole': 'heart'},
    ],
    'palette': {'heart': '#FF4D6D'},
    'silhouette': {'heart': [[0, 0], [0, 1], [1, 0]]},
  };
  final level = const LevelJsonDecoder().decode(json);
  final map = const LevelJsonEncoder().toMap(
    levelId: level.id.value, board: level.board,
    palette: level.palette, silhouette: level.silhouette);
  expect(map['silhouette'], json['silhouette']);
});
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

Add to the `Level(...)` construction in `_decodeStrict` (after `palette:` line):
```dart
      silhouette: _optionalSilhouette(json, 'silhouette'),
```
Add the parser method (reuses `_position` shape rules):
```dart
  Map<String, List<Position>>? _optionalSilhouette(
      Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! Map) {
      throw FormatException('"$key" must be an object when present');
    }
    final result = <String, List<Position>>{};
    value.forEach((k, v) {
      if (k is! String || v is! List) {
        throw FormatException('"$key" must map roles to cell lists');
      }
      result[k] = [for (final cell in v) _position(cell, 'silhouette:$k')];
    });
    return result;
  }
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/serialization/level_json_decoder.dart test/infrastructure/serialization/level_json_decoder_test.dart
git commit -m "feat(front/serialization): decode silhouette strictly (golden round-trip)

Refs #114

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 (front): Themed producer emits silhouette + regenerate fixtures

**Files:**
- Modify: `tool/level_production/themed_producer.dart`
- Test: `test/tool/level_production/themed_producer_test.dart` (add case)
- Regenerate: `tool/level_production/themed/themed-{heart,happy_face,bunny}.json` (+ previews + manifest)

**Interfaces:**
- Consumes: encoder `silhouette` param (Task 2), `MaskSpec.regions` (role + `Set<Position> cells`).
- Produces: themed JSON now contains `silhouette` with every region's cells (sorted by row, then col, for determinism).

- [ ] **Step 1: Write failing test** — assert the produced JSON string contains a `silhouette` object whose `heart` list length equals the mask region cell count.

```dart
test('produceThemed emits silhouette covering every region cell', () {
  final mask = parseMaskSpec('''
name: t
legend:
  H = heart : #FF4D6D
grid:
HH
HH
''');
  final result = produceThemed(mask, coverageTarget: 0.5, maxPathLen: 2, seeds: const [0, 1, 2]);
  final decoded = const LevelJsonDecoder().decode(
      jsonDecode(result.json) as Map<String, Object?>);
  expect(decoded.silhouette!['heart'], hasLength(4)); // 2x2 region
});
```
(Add imports: `dart:convert`, the decoder.)

- [ ] **Step 2: Run — expect FAIL**

`flutter test test/tool/level_production/themed_producer_test.dart`

- [ ] **Step 3: Implement**

In `themed_producer.dart`, build the silhouette from `mask.regions` and pass it to the encoder. Replace the `json: const LevelJsonEncoder().encode(levelId: levelId, board: bestBoard, palette: mask.palette)` call with:
```dart
    json: const LevelJsonEncoder().encode(
      levelId: levelId,
      board: bestBoard,
      palette: mask.palette,
      silhouette: {
        for (final region in mask.regions)
          region.role: (region.cells.toList()
            ..sort((a, b) =>
                a.row != b.row ? a.row - b.row : a.col - b.col)),
      },
    ),
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Regenerate the 3 fixtures**

```bash
export PATH="/opt/homebrew/bin:$PATH"
cd MazePruebaFront
TMP=$(mktemp -d); cp tool/level_production/masks/{heart,happy_face,bunny}.mask "$TMP"/
dart run tool/level_production/produce_themed.dart --masks-dir "$TMP" \
  --out tool/level_production/themed --coverage 0.9 --seeds 0..150 --maxlen 8
```
Expected: `✓ themed-heart seed 74`, `✓ themed-happy_face seed 94`, `✓ themed-bunny seed 11` (arrows unchanged vs current; each JSON now has `silhouette`). Verify: `grep -c silhouette tool/level_production/themed/themed-*.json` → 1 each.

- [ ] **Step 6: Commit**

```bash
git add tool/level_production/themed_producer.dart test/tool/level_production/themed_producer_test.dart tool/level_production/themed/
git commit -m "feat(front/tooling): emit silhouette in themed fixtures; regenerate

Refs #114

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 (front): `GamePlaying` exposes `silhouette`

**Files:**
- Modify: `lib/application/state/game_state.dart` (add field to `GamePlaying`)
- Modify: `lib/application/state/game_controller.dart` (populate from `level.silhouette` everywhere `palette` is set)
- Test: `test/application/state/game_controller_themed_space_test.dart` (add assertion)

**Interfaces:**
- Consumes: `Level.silhouette` (Task 1).
- Produces: `GamePlaying.silhouette` (`Map<String, List<Position>>?`), populated from the mounted level.

- [ ] **Step 1: Write failing test** — after loading a themed level whose fixture has a silhouette, `state.silhouette` is non-null and matches the level. Follow the existing pattern in this file that asserts `state.palette`. Mirror it for `silhouette`.

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

In `game_state.dart`, `GamePlaying`: add `final Map<String, List<Position>>? silhouette;` next to `palette`, add to constructor and to any `copyWith`/`props`/`==` the class already defines (mirror `palette` exactly — same nullability, same places). Import `Position` if needed.
In `game_controller.dart`: everywhere a `GamePlaying(...)` is built with `palette: level.palette` (or `palette: _level.palette`), add `silhouette: <sameSource>.silhouette`. Search the file for `palette:` and mirror each site.

- [ ] **Step 4: Run — expect PASS** (this file + `flutter test test/application/`)

- [ ] **Step 5: Commit**

```bash
git add lib/application/state/game_state.dart lib/application/state/game_controller.dart test/application/state/game_controller_themed_space_test.dart
git commit -m "feat(front/state): thread silhouette through GamePlaying

Refs #114

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 (front): `SilhouettePainter` + board integration

**Files:**
- Create: `lib/presentation/game/painters/silhouette_painter.dart`
- Modify: `lib/presentation/game/widgets/board_widget.dart`
- Test: `test/presentation/game/painters/silhouette_painter_test.dart` (new)

**Interfaces:**
- Consumes: `GamePlaying.silhouette` + `state.palette` (Task 5), `ThemedArrowColorResolver.parseHexColor`.
- Produces: a `CustomPainter` that fills each silhouette cell with `parseHexColor(palette[role])` at the given alpha; painted between `BoardSurfacePainter` and the arrows.

- [ ] **Step 1: Write failing test** — a `SilhouettePainter` with one role/cell records exactly one `drawRect` at the expected frame offset. Use a recording canvas (see `test/presentation/game/widgets/board_view_masked_space_test.dart` for the project's canvas-recording helper) and assert one filled rect at `(col-minCol)*cell, (row-minRow)*cell`. Assert a cell whose role hex is invalid is skipped (0 rects).

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

```dart
// lib/presentation/game/painters/silhouette_painter.dart
import 'package:flutter/material.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../arrow_color_resolver.dart';

/// Relleno de silueta temática (front#114): pinta cada celda de región con el
/// color de su rol (tenue), DEBAJO de las flechas, para que la figura no tenga
/// huecos visibles. Dato opaco: no afecta solubilidad ni hit-testing. Se salta
/// roles ausentes en la paleta o con hex inválido (misma tolerancia que el seam
/// de color de flechas).
class SilhouettePainter extends CustomPainter {
  final BoundingBox frame;
  final double cell;
  final Map<String, List<Position>> silhouette;
  final Map<String, String> palette;
  final double alpha;

  const SilhouettePainter({
    required this.frame,
    required this.cell,
    required this.silhouette,
    required this.palette,
    this.alpha = 0.30,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in silhouette.entries) {
      final hex = palette[entry.key];
      if (hex == null) continue;
      final base = ThemedArrowColorResolver.parseHexColor(hex);
      if (base == null) continue;
      final paint = Paint()..color = base.withValues(alpha: alpha);
      for (final p in entry.value) {
        final rect = Rect.fromLTWH(
          (p.col - frame.minCol) * cell,
          (p.row - frame.minRow) * cell,
          cell, cell,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SilhouettePainter old) =>
      old.frame != frame ||
      old.cell != cell ||
      old.silhouette != silhouette ||
      old.palette != palette ||
      old.alpha != alpha;
}
```

In `board_widget.dart`, inside the `Stack` `children` of `_boardContent`, immediately AFTER the `Positioned.fill(child: CustomPaint(painter: BoardSurfacePainter(...)))` and BEFORE the arrows loop, insert:

```dart
          if (state.silhouette != null && state.palette != null)
            Positioned.fill(
              child: CustomPaint(
                painter: SilhouettePainter(
                  frame: frame,
                  cell: cell,
                  silhouette: state.silhouette!,
                  palette: state.palette!,
                ),
              ),
            ),
```
Add `import '../painters/silhouette_painter.dart';`.

- [ ] **Step 4: Run — expect PASS** (`flutter test test/presentation/game/`)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/game/painters/silhouette_painter.dart lib/presentation/game/widgets/board_widget.dart test/presentation/game/painters/silhouette_painter_test.dart
git commit -m "feat(front/presentation): paint themed silhouette under arrows

Refs #114

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Full front suite green**

`flutter test` → all pass. Then AI_HISTORY entry + commit.

---

## Task 7 (back): Seed accepts + validates `silhouette`

**Files:**
- Modify: `prisma/seed.ts` (`LevelFixture` + `toData`)
- Modify: `src/infrastructure/database/level-paint.validator.ts`
- Test: `src/infrastructure/database/curated-levels.spec.ts` (add cases) and/or the paint validator's own spec.

**Interfaces:**
- Consumes: fixture JSON with `silhouette`.
- Produces: `validateLevelSilhouette` (or extended `validateLevelPaint`) rejecting a silhouette whose role ∉ palette or whose cell is out of bounds; `toData` hoists `silhouette` into `data`.

- [ ] **Step 1: Write failing tests** (Jest, AAA) in the paint validator spec:
```ts
it('rejects silhouette role not in palette', () => {
  expect(() => validateLevelPaint({
    levelId: 't', cols: 4, rows: 4,
    palette: { heart: '#FF4D6D' },
    silhouette: { ghost: [[0, 0]] },
    arrows: [{ id: 'a', headDir: 'right', cells: [[0,0],[0,1]], paintRole: 'heart' }],
  } as any)).toThrow(/silhouette/i);
});
it('rejects silhouette cell out of bounds', () => {
  expect(() => validateLevelPaint({
    levelId: 't', cols: 4, rows: 4,
    palette: { heart: '#FF4D6D' },
    silhouette: { heart: [[9, 9]] },
    arrows: [{ id: 'a', headDir: 'right', cells: [[0,0],[0,1]], paintRole: 'heart' }],
  } as any)).toThrow(/bounds|silhouette/i);
});
it('accepts a valid silhouette', () => {
  expect(() => validateLevelPaint({
    levelId: 't', cols: 4, rows: 4,
    palette: { heart: '#FF4D6D' },
    silhouette: { heart: [[0, 0], [0, 1]] },
    arrows: [{ id: 'a', headDir: 'right', cells: [[0,0],[0,1]], paintRole: 'heart' }],
  } as any)).not.toThrow();
});
```

- [ ] **Step 2: Run — expect FAIL**

`cd MazePruebaBack && npx jest src/infrastructure/database/level-paint.validator.spec.ts`

- [ ] **Step 3: Implement**

In `level-paint.validator.ts`, extend the fixture type to accept `silhouette?: Record<string, [number, number][]>` and add, after the palette checks:
```ts
  if (fixture.silhouette) {
    const roles = new Set(Object.keys(fixture.palette ?? {}));
    for (const [role, cells] of Object.entries(fixture.silhouette)) {
      if (!roles.has(role)) {
        throw new Error(`silhouette role "${role}" is not in palette`);
      }
      for (const [row, col] of cells) {
        if (row < 0 || row >= fixture.rows || col < 0 || col >= fixture.cols) {
          throw new Error(`silhouette cell [${row},${col}] out of bounds for "${role}"`);
        }
      }
    }
  }
```
In `seed.ts`: add `silhouette?: Record<string, [number, number][]>;` to `LevelFixture`; in `toData`, after the `palette` spread add:
```ts
    ...(fixture.silhouette !== undefined ? { silhouette: fixture.silhouette } : {}),
```

- [ ] **Step 4: Run — expect PASS**

`npx jest src/infrastructure/database/level-paint.validator.spec.ts src/infrastructure/database/curated-levels.spec.ts`

- [ ] **Step 5: Commit**

```bash
git add prisma/seed.ts src/infrastructure/database/level-paint.validator.ts src/infrastructure/database/level-paint.validator.spec.ts
git commit -m "feat(back/db): validate and hoist themed silhouette in seed

Refs #50

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8 (back): Copy regenerated fixtures + manifest + CONTEXT/ADR

**Files:**
- Overwrite: `prisma/levels/t-{heart,happy-face,bunny}.json` from the front themed JSON (id→`t-*`, `section:themed`, hoist `palette` AND `silhouette` before `arrows`).
- Modify: `prisma/levels/manifest.md`
- Modify: `CONTEXT.md`; Create: `docs/adr/00XX-themed-silhouette-on-wire.md`
- Test: `src/infrastructure/database/curated-levels.spec.ts` (re-certifies fixtures on disk)

**Interfaces:**
- Consumes: front themed JSON with `silhouette` (Task 4).

- [ ] **Step 1: Transform the three fixtures** — reuse the front→back transform, now carrying `silhouette` (field order: `levelId, section, cols, rows, palette, silhouette, arrows`):

```bash
python3 - <<'PY'
import json, collections
F="../MazePruebaFront/tool/level_production/themed"; B="prisma/levels"
for src, dst in {"themed-heart":"t-heart","themed-happy_face":"t-happy-face","themed-bunny":"t-bunny"}.items():
    j=json.load(open(f"{F}/{src}.json"), object_pairs_hook=collections.OrderedDict)
    out=collections.OrderedDict()
    out["levelId"]=dst; out["section"]="themed"
    out["cols"]=j["cols"]; out["rows"]=j["rows"]
    out["palette"]=j["palette"]; out["silhouette"]=j["silhouette"]; out["arrows"]=j["arrows"]
    open(f"{B}/{dst}.json","w").write(json.dumps(out, indent=2)+"\n")
    print("wrote", dst)
PY
```

- [ ] **Step 2: Certify without a DB**

`npx jest src/infrastructure/database/curated-levels.spec.ts` → green (validates the new silhouette too).

- [ ] **Step 3: Update `manifest.md`** — add a line under the themed table noting that themed fixtures now carry `silhouette` (role→region cells) for the visual fill (front#114 / back#50).

- [ ] **Step 4: Update `CONTEXT.md` + write ADR** — CONTEXT.md: change the "mask does not travel on the wire" note to record that its silhouette (region cells) now travels as an opaque paint consequence. New ADR documents the decision, alternatives (post-fill arrows, full rewrite) and why silhouette-on-wire was chosen.

- [ ] **Step 5: Reseed in Docker + verify**

```bash
cd /Users/isaac_rs/Desktop/UCAB/ArrowMaze
docker compose up --build -d back
docker logs arrowmaze-back 2>&1 | grep -E "seeded t-|Seed complete"
curl -s http://localhost:3000/levels/t-heart | python3 -c "import json,sys;d=json.load(sys.stdin);print('silhouette roles', list(d.get('silhouette',{})))"
```
Expected: `Seed complete: 18 levels`; `silhouette roles ['heart']`.

- [ ] **Step 6: Commit**

```bash
git add prisma/levels/ CONTEXT.md docs/adr/
git commit -m "feat(back/db): seed themed fixtures with silhouette; revise wire ADR

Refs #50

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Visual check + PRs

- [ ] Rebuild front container, open `http://localhost:8080`, open the themed section, confirm heart/happy-face/bunny render with **no visible holes** (region color tint under the arrows). Tune `alpha` in `SilhouettePainter` if needed (single constant).
- [ ] AI_HISTORY entries in both repos.
- [ ] Push both branches; open 2 PRs via `gh api` (branch names contain `#`): front `feat/#114-...` (closes #114), back `feat/#50-...` (closes #50). Do NOT merge.

---

## Self-Review

- **Spec coverage:** wire field (T2/T3/T7), tooling emit (T4), decoder/Level (T1/T3), state (T5), painter (T6), back seed+validate (T7), fixtures+manifest+CONTEXT+ADR (T8), reseed+visual (T8/T9), branches/PRs (T9). All spec sections mapped.
- **Placeholders:** T5/T6-step1 describe "mirror the `palette` pattern / use the project's canvas-recording helper" rather than inline code — intentional, because the exact `GamePlaying`/canvas-recorder shapes must be read at implementation time; every other step has concrete code. Implementer must open those two files first.
- **Type consistency:** `Map<String, List<Position>>?` used for `silhouette` in Level, encoder, decoder, GamePlaying, painter; back uses `Record<string, [number, number][]>`. `parseHexColor` is the static on `ThemedArrowColorResolver`. Consistent across tasks.
