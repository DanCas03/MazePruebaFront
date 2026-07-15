# Generador por bandas concéntricas — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar el anillo perimetral del generador: colocación interior-primero por bandas concéntricas con cuota proporcional y dirección factible, manteniendo DAG, determinismo y el camino temático byte-estable.

**Architecture:** Helpers puros nuevos (`band_layout.dart`) + rework de `GraphBoardGenerator.generate()`; `generateThemed()` y `_randomBentArrow` no se tocan. Spec: `docs/superpowers/specs/2026-07-15-generator-band-density-design.md`.

**Tech Stack:** Flutter/Dart, flutter_test.

## Global Constraints

- Rama de trabajo: `feat/generator-band-density` (main protegida; PR al final, el usuario decide merge).
- `generateThemed()` byte-estable: el golden inline de `test/tool/level_production/themed_producer_test.dart` debe pasar SIN cambios en todas las tareas.
- Cada commit incluye su entrada `AI_HISTORY.MD` (numeración: siguiente ≈ 086, verificar la última al empezar). Conventional Commits.
- Sin knobs públicos nuevos: `ILevelGenerator` y `GeneratorConfig` intactos.
- Todos los comandos se ejecutan desde `MazePruebaFront/`.

---

### Task 1: Helpers puros de bandas y cuotas

**Files:**
- Create: `lib/infrastructure/generators/band_layout.dart`
- Test: `test/infrastructure/generators/band_layout_test.dart`

**Interfaces:**
- Produces: `List<List<Position>> concentricBands({required int cols, required int rows})` (índice 0 = banda más interior; particiona todas las celdas) y `List<int> largestRemainderQuotas(int total, List<int> sizes)` (suma exacta = `total`).

- [ ] **Step 1: Crear `band_layout.dart`**

```dart
import 'dart:math';

import '../../domain/game_core/value_objects/position.dart';

/// Bandas concéntricas de un rectángulo cols×rows, de la MÁS INTERIOR
/// (índice 0) a la más exterior. Distancia al borde
/// d = min(row, col, rows-1-row, cols-1-col); el rango [0..maxD] se divide
/// en k = min(3, maxD + 1) bandas de ancho igual. Tableros pequeños
/// degeneran a 1–2 bandas. Toda celda cae exactamente en una banda.
List<List<Position>> concentricBands({required int cols, required int rows}) {
  final maxD = (min(rows, cols) - 1) ~/ 2;
  final k = min(3, maxD + 1);
  final bands = List.generate(k, (_) => <Position>[]);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final d = [r, c, rows - 1 - r, cols - 1 - c].reduce(min);
      final band = ((maxD - d) * k) ~/ (maxD + 1); // 0 = interior (d alto)
      bands[band].add(Position(row: r, col: c));
    }
  }
  return bands;
}

/// Reparto por mayor resto: cuotas ∝ sizes, suma exacta = total.
List<int> largestRemainderQuotas(int total, List<int> sizes) {
  final sum = sizes.fold<int>(0, (a, b) => a + b);
  if (sum == 0) return List.filled(sizes.length, 0);
  final exact = [for (final s in sizes) total * s / sum];
  final quotas = [for (final e in exact) e.floor()];
  var remaining = total - quotas.fold<int>(0, (a, b) => a + b);
  final order = List.generate(sizes.length, (i) => i)
    ..sort((a, b) => (exact[b] - quotas[b]).compareTo(exact[a] - quotas[a]));
  for (final i in order) {
    if (remaining == 0) break;
    quotas[i]++;
    remaining--;
  }
  return quotas;
}
```

- [ ] **Step 2: Delegar los tests a un subagente** con este prompt:

> Escribe `MazePruebaFront/test/infrastructure/generators/band_layout_test.dart` (flutter_test, patrón AAA, nombres `should_..._when_...`) para `lib/infrastructure/generators/band_layout.dart`. Casos para `concentricBands`: (1) 20×20 ⇒ 3 bandas, particionan las 400 celdas sin solaparse, banda 0 solo contiene celdas con d≥6 y banda 2 incluye todo el perímetro d=0; (2) 2×2 (maxD=0) ⇒ 1 banda con las 4 celdas; (3) 6×8 (maxD=2) ⇒ 3 bandas, una por distancia. Casos para `largestRemainderQuotas`: (1) suma exacta = total con restos (p. ej. total=10, sizes=[1,1,1]); (2) proporcionalidad (total=30, sizes=[10,20,30] ⇒ [5,10,15]); (3) sizes todo ceros ⇒ todo ceros; (4) total=0 ⇒ todo ceros. No modifiques código de producción.

- [ ] **Step 3: Verificar** — Run: `flutter test test/infrastructure/generators/band_layout_test.dart` → PASS.

- [ ] **Step 4: Commit** (incluye entrada AI_HISTORY)

```bash
git add lib/infrastructure/generators/band_layout.dart test/infrastructure/generators/band_layout_test.dart AI_HISTORY.MD
git commit -m "feat(infra): add concentric band layout and quota helpers"
```

---

### Task 2: Test estadístico de densidad (RED)

**Files:**
- Test: `test/infrastructure/generators/graph_board_density_test.dart`

**Interfaces:**
- Consumes: `concentricBands` (Task 1), `GraphBoardGenerator.generate(cols:, rows:, arrowCount:, maxPathLen:, seed:)`.

- [ ] **Step 1: Delegar el test a un subagente** con este prompt:

> Escribe `MazePruebaFront/test/infrastructure/generators/graph_board_density_test.dart` (flutter_test, AAA). Para los seeds `[11, 22, 33, 44, 55]`: genera con `GraphBoardGenerator().generate(cols: 20, rows: 20, arrowCount: 60, maxPathLen: 4, seed: s)`. Para cada tablero calcula el conjunto de celdas ocupadas (unión de `arrow.cells` de `board.arrows`), y con `concentricBands(cols: 20, rows: 20)` la densidad de la banda interior (ocupadas∩banda0 / |banda0|) y la densidad global (ocupadas / 400). Assert: el promedio sobre los 5 seeds de `densidadInterior / densidadGlobal` ≥ 0.6. Añade un segundo test que verifique que cada tablero generado sigue siendo no vacío y sin solapes (cada celda usada por una sola flecha). Documenta en el comentario de cabecera que este test es el guardián del fix de densidad (spec 2026-07-15-generator-band-density-design.md).

- [ ] **Step 2: Verificar que está ROJO con el generador actual** — Run: `flutter test test/infrastructure/generators/graph_board_density_test.dart` → FAIL en el assert de densidad (el interior queda desierto hoy). Si saliera verde, revisar el umbral/metric con el usuario antes de seguir. **No commitear aún** (se commitea en verde con la Task 3).

---

### Task 3: `generate()` por bandas con dirección factible (GREEN)

**Files:**
- Modify: `lib/infrastructure/generators/graph_board_generator.dart` (método `generate`, líneas ~39-90; añadir `_bentArrowFromPool`; import de `band_layout.dart`)

**Interfaces:**
- Consumes: `concentricBands`, `largestRemainderQuotas` (Task 1).
- Produces: misma firma pública `generate(...)`; `_randomBentArrow`, `_randomHeadWithClearLane`, `_freeNeighbors` y `generateThemed` quedan intactos.

- [ ] **Step 1: Reemplazar el cuerpo de `generate()`**

```dart
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
  final occupied = <Position>{};

  // Colocación interior-primero por bandas concéntricas (spec 2026-07-15):
  // las flechas centrales se colocan con el tablero vacío (carriles largos
  // baratos) y el perímetro al final, cuando solo los carriles cortos son
  // viables — homogeneidad por construcción, mismo invariante DAG.
  final bands = concentricBands(cols: cols, rows: rows);
  final quotas =
      largestRemainderQuotas(arrowCount, [for (final b in bands) b.length]);

  var carry = 0; // cuota no colocada que rueda a la banda siguiente
  var totalAttempts = 0;
  for (var i = 0; i < bands.length; i++) {
    final pool = bands[i];
    final target = quotas[i] + carry;
    var bandPlaced = 0;
    var attempts = 0;
    final maxAttempts = pool.length * 30;
    while (bandPlaced < target && attempts < maxAttempts) {
      attempts++;
      final candidate = _bentArrowFromPool(
          rng, space, pool, placed.length, maxPathLen, occupied);
      if (candidate == null) continue;

      assert(candidate.cells.every((c) => !occupied.contains(c)),
          'candidate overlaps the incremental occupancy state');
      assert(
          space
              .exitLane(candidate.head, candidate.headDirection)
              .every((p) => !occupied.contains(p)),
          'candidate exit lane is blocked at placement time');

      placed.add(candidate);
      occupied.addAll(candidate.cells);
      bandPlaced++;
    }
    carry = target - bandPlaced;
    totalAttempts += attempts;
  }

  if (placed.length < arrowCount) {
    _logger?.warn(
      'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
      'in ${cols}x$rows board after $totalAttempts attempts (seed=$seed)',
      'GraphBoardGenerator',
    );
  }

  return ArrowBoard(arrows: placed, space: space);
}
```

- [ ] **Step 2: Añadir `_bentArrowFromPool`** (junto a `_randomBentArrow`, que NO se toca — lo sigue usando el camino temático byte-estable):

```dart
/// Variante de campaña por bandas: muestrea la cabeza de [pool] y elige la
/// dirección AL AZAR ENTRE LAS FACTIBLES (carril libre), en vez de imponerla
/// a priori — una celda vale si cualquiera de sus carriles está libre. El
/// cuerpo crece igual que en [_randomBentArrow] y puede salir del pool.
Arrow? _bentArrowFromPool(Random rng, BoardSpace space, List<Position> pool,
    int index, int maxPathLen, Set<Position> occupied) {
  Position? head;
  Direction? dir;
  for (var t = 0; t < 20 && head == null; t++) {
    final cell = pool[rng.nextInt(pool.length)];
    if (occupied.contains(cell)) continue;
    final feasible = <Direction>[
      for (final d in Direction.values)
        if (space.exitLane(cell, d).every((p) => !occupied.contains(p))) d
    ];
    if (feasible.isEmpty) continue;
    head = cell;
    dir = feasible[rng.nextInt(feasible.length)];
  }
  if (head == null || dir == null) return null;

  final blocked = <Position>{...occupied, head, ...space.exitLane(head, dir)};
  final body = <Position>[head]; // head..tail; se invierte al final
  final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
  var cursor = head;
  while (body.length < targetLen) {
    final options = _freeNeighbors(cursor, space, blocked);
    if (options.isEmpty) break; // acepta cuerpo más corto
    final next = options[rng.nextInt(options.length)];
    body.add(next);
    blocked.add(next);
    cursor = next;
  }
  if (body.length < 2) return null;

  return Arrow(
    id: ArrowId('arrow-$index'),
    cells: body.reversed.toList(),
    headDirection: dir,
  );
}
```

Añadir el import: `import 'band_layout.dart';`. Actualizar el comentario de cabecera de la clase: el invariante DAG se mantiene; retirar las menciones a "byte a byte idéntico" del camino de campaña en `_randomHeadWithClearLane` solo si tocan a `generate` (ese helper queda como está, usado por temático).

- [ ] **Step 3: Verificar GREEN + aislamiento**

Run: `flutter test test/infrastructure/generators/ test/tool/level_production/themed_producer_test.dart test/infrastructure/serialization/level_generation_determinism_test.dart`
Expected: PASS density, band_layout, invariantes (`graph_board_generator_test.dart`), themed (golden inline intacto), determinismo y perf. FAIL esperado únicamente: `test/tool/level_production/golden_boards_regression_test.dart` (se recaptura en Task 4).

- [ ] **Step 4: Commit** (incluye AI_HISTORY)

```bash
git add lib/infrastructure/generators/graph_board_generator.dart test/infrastructure/generators/graph_board_density_test.dart AI_HISTORY.MD
git commit -m "feat(infra): place arrows inner-first by concentric bands for homogeneous density"
```

---

### Task 4: Recapturar goldens de campaña como forward guard

**Files:**
- Modify: `test/fixtures/golden_boards/cand-t1-s101.json`, `test/fixtures/golden_boards/cand-t5-s918.json` (recaptura)
- Modify: `test/tool/level_production/golden_boards_regression_test.dart` (solo el doc-comment)
- Create+Delete: `tool/regen_goldens.dart` (script efímero)

**Interfaces:**
- Consumes: `CandidateSpec`, `rampStepFor`, `produceCandidate` (ya existentes en `tool/level_production/`).

- [ ] **Step 1: Crear `tool/regen_goldens.dart`**

```dart
import 'dart:io';

import 'level_production/candidate_producer.dart';
import 'level_production/ramp.dart';

void main() {
  final specs = {
    'cand-t1-s101': CandidateSpec(step: rampStepFor(1), seed: 101),
    'cand-t5-s918': CandidateSpec(step: rampStepFor(5, finale: true), seed: 918),
  };
  for (final e in specs.entries) {
    File('test/fixtures/golden_boards/${e.key}.json')
        .writeAsStringSync(produceCandidate(e.value).json);
    stdout.writeln('recaptured ${e.key}');
  }
}
```

Run: `dart run tool/regen_goldens.dart` → `recaptured cand-t1-s101` / `recaptured cand-t5-s918`. Después: borrar el script (`git status` debe quedar sin él).

- [ ] **Step 2: Reescribir el doc-comment del test golden** (líneas 9-14) — nueva misión:

```dart
/// Forward regression guard (patrón back#39): fija el output del generador
/// por bandas (spec 2026-07-15-generator-band-density-design.md) para
/// (tier, seed). Si rompe SIN un cambio deliberado del generador, hay un bug
/// de reproducibilidad. Ante un cambio deliberado, recapturar con un script
/// puntual que escriba produceCandidate(spec).json en test/fixtures/.
```

- [ ] **Step 3: Verificar** — Run: `flutter test test/tool/level_production/golden_boards_regression_test.dart` → PASS (2/2).

- [ ] **Step 4: Commit** (incluye AI_HISTORY)

```bash
git add test/fixtures/golden_boards/ test/tool/level_production/golden_boards_regression_test.dart AI_HISTORY.MD
git commit -m "test(tooling): recapture campaign goldens as forward guard for banded generator"
```

---

### Task 5: README, suite completa y PR

**Files:**
- Modify: `README.md` (sección del modo generado: una nota de que la distribución es homogénea por bandas concéntricas, con referencia al spec)

- [ ] **Step 1: Añadir la nota al README** en la sección que describa el modo "Generar nivel"/generador (localizarla con `grep -n "Generar\|generador" README.md`). Una o dos frases: colocación interior-primero por bandas concéntricas ⇒ densidad homogénea; mismo seed ⇒ mismo tablero.

- [ ] **Step 2: Suite completa** — Run: `flutter test` → PASS total (0 fallos). Y `flutter analyze` sin issues nuevos.

- [ ] **Step 3: Commit + push + PR**

```bash
git add README.md AI_HISTORY.MD
git commit -m "docs(readme): note homogeneous band-based distribution in generated mode"
git push -u origin feat/generator-band-density
gh pr create --title "feat(infra): homogeneous arrow density via concentric bands" --body "Closes nothing pending. Spec: docs/superpowers/specs/2026-07-15-generator-band-density-design.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

El usuario decide el merge.
