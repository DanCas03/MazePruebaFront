# Themed Masked Board Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Los niveles temáticos se montan sobre un `MaskedSpace` cuya silueta ES la figura (viaja como campo `silhouette` en el wire), con interior 100% pintado como tablero y flechas variadas a densidad ≥90%.

**Architecture:** El campo `silhouette` (rol → celdas del fill de la región) replica el carril opaco de `paint`/ADR 0004 en el back (seed valida forma, dominio no interpreta, mapper passthrough) y en el front se decodifica estricto hasta `Level`; el seam `_mountedBoard` (hoy identidad, PR #107) vuelve a montar `MaskedSpace` cuando hay silueta — painter enmascarado y hit-testing space-aware ya existen y están testeados. La densidad la aporta un modo denso nuevo del generador temático (interior-first + sesgo a codos + pasadas de relleno) con tests guardianes que impiden la degeneración en flechas rectas.

**Tech Stack:** Flutter/Dart (Riverpod, Equatable), NestJS/TypeScript (Prisma, Jest), tooling Dart puro en `tool/level_production/`.

**Spec:** `docs/superpowers/specs/2026-07-16-themed-masked-board-redesign.md` (front repo).

## Global Constraints

- Supersede front#114/PR#115 y back#50/PR#51: **no reutilizar nada de esas ramas** (ni código ni fixtures).
- Prioridad #1: fuera de la silueta no se pinta nada ni se aceptan taps; dentro, todo es superficie de tablero.
- Densidad global ≥90% por máscara regenerada; regiones de detalle al 100% (si una celda de detalle es irrellenable con flechas ≥2 celdas, se ajusta la máscara).
- Variedad: longitudes 2-5 mezcladas; ≥40% de flechas con ≥1 codo; sin 3+ flechas rectas paralelas adyacentes.
- **El conejo NO se regenera**: `themed-bunny` conserva sus 37 flechas exactas (16×20); solo gana `silhouette`.
- Corazón: máscara nueva 36×24 (cols×rows). Cara feliz: 24×22 actual, regenerada densa.
- Los temáticos NO participan de la banda 9:16 (`AspectBand` no aplica a máscaras).
- Campaña intacta: `RectSpace`, goldens, ramp 9:16 — cero cambios de comportamiento.
- Convenciones del proyecto: Clean Architecture por capas, AAA con Mockito codegen (front) / mocks a mano (back), Conventional Commits por fragmento, entrada en AI_HISTORY.MD por fragmento, actualizar README si cambia funcionalidad pública.
- CI front: `flutter analyze` + `flutter test`. CI back: `npm run lint:check` + `npm test` + `npm run test:e2e` + `npm run build`.
- Los tests de cada tarea se delegan a un subagente con el brief de casos de la tarea (preferencia del maintainer: los planes no llevan cuerpos de test completos, llevan la lista exacta de casos).

---

## Task 0: Issues y ramas nuevas

**Files:** ninguno (GitHub + git).

- [ ] **Step 1:** Crear issue en front (`gh issue create`) — título: "Tablero temático enmascarado: silueta desde el wire + generador denso"; cuerpo: resumen del spec §1-§6 con link al spec; labels `enhancement,ready-for-agent`. Anotar su número `F`.
- [ ] **Step 2:** Crear issue en back — título: "Servir `silhouette` (rol → celdas de región) en niveles temáticos + seeds densos"; cuerpo: mapa de cambios (fixture→seed→validator→dominio→repo→mapper→e2e) con link al spec del front; labels `enhancement,ready-for-agent`. Anotar su número `B`.
- [ ] **Step 3:** Front: crear rama `feat/#F-themed-masked-board` desde `main`, cherry-pick del commit de spec/plan de `feat/themed-masked-board-redesign` (52267e5 y el commit del plan). Back: crear rama `feat/#B-themed-silhouette-mask` desde `main`.
- [ ] **Step 4:** Comentar en PR #115 (front) y PR #51 (back): "Superseded por #F / #B según spec 2026-07-16-themed-masked-board-redesign". **NO cerrarlos** — los cierra el maintainer.

---

## FASE A — Front: dominio + wire

### Task 1: `Level.silhouette` (dominio)

**Files:**
- Modify: `lib/domain/board/entities/level.dart`
- Test: `test/domain/board/entities/level_test.dart` (extender)

**Interfaces:**
- Produces: `Level.silhouette` de tipo `Map<String, Set<Position>>?` (rol → celdas del fill; `null` = campaña). Getter derivado `Set<Position>? get silhouetteUnion` (unión de todas las regiones, `null` si no hay silueta).

- [ ] **Step 1: Test primero (subagente, casos exactos):**
  - construye `Level` con `silhouette` válido (flechas dentro de la unión) → expone el campo y `silhouetteUnion` correcto.
  - `silhouette: null` → `silhouetteUnion == null` (campaña intacta, `props` compatibles).
  - flecha con una celda FUERA de la unión → `InvalidLevelException`.
  - celda de silueta fuera de la caja `cols×rows` del board → `InvalidLevelException`.
  - silueta con mapa vacío `{}` → `InvalidLevelException` (si está presente, debe tener ≥1 región con ≥1 celda).
- [ ] **Step 2:** Run `flutter test test/domain/board/entities/level_test.dart` → FAIL (campo inexistente).
- [ ] **Step 3: Implementación.** Añadir al constructor named param `this.silhouette` y validar en el cuerpo (mismo estilo de los invariantes existentes):

```dart
final Map<String, Set<Position>>? silhouette;

Set<Position>? get silhouetteUnion => silhouette == null
    ? null
    : silhouette!.values.fold(<Position>{}, (acc, cells) => acc..addAll(cells));
```

Validaciones en el constructor cuando `silhouette != null`: no vacío, toda celda dentro de `board.space.bounds` (usar `contains` de la caja), y toda celda de toda flecha ∈ `silhouetteUnion`. Añadir `silhouette` a `props`.
- [ ] **Step 4:** Run test → PASS. `flutter analyze` limpio.
- [ ] **Step 5:** Commit `feat(front/domain): add silhouette field to Level with containment invariants (#F)` + entrada AI_HISTORY.

### Task 2: Decoder/Encoder de `silhouette`

**Files:**
- Modify: `lib/infrastructure/serialization/level_json_decoder.dart`, `level_json_encoder.dart`
- Test: `test/infrastructure/serialization/level_json_decoder_test.dart`, `level_json_encoder_test.dart` (extender)

**Interfaces:**
- Consumes: `Level.silhouette` (Task 1).
- Produces: clave wire `"silhouette": { "<rol>": [[row,col], ...] }` opcional; `LevelJsonEncoder.toMap`/`encode` ganan named param `Map<String, Set<Position>>? silhouette`. Golden `encode(decode(x)) == x` se mantiene.

- [ ] **Step 1: Tests primero (subagente):** decoder — silhouette ausente → `Level.silhouette == null`; presente válido → mapa con `Set<Position>` correcto; celda malformada (`[1]`, `["a",2]`), rol no-string, valor no-lista → `FormatException`; flecha fuera de silueta → `FormatException` (invariante de dominio re-lanzada, patrón existente). Encoder — con silhouette emite la clave con celdas ordenadas row-major (orden determinista para byte-estabilidad); sin silhouette no emite la clave; round-trip golden sobre un JSON temático con silhouette.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Decoder: en `_decodeStrict`, tras `palette`, parsear `silhouette` con helper nuevo `_optionalSilhouette(json)` (valida `Map<String, List>` y cada celda como par int reutilizando `_position`); pasar al constructor de `Level`. Encoder: en `toMap`, emitir con spread condicional (como `palette`), serializando cada `Set<Position>` ordenado por `(row, col)`:

```dart
...(silhouette != null
    ? {
        'silhouette': {
          for (final e in silhouette.entries)
            e.key: (e.value.toList()
                  ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col))
                .map((p) => [p.row, p.col])
                .toList(),
        },
      }
    : {}),
```
- [ ] **Step 4:** Run tests → PASS. Analyze limpio.
- [ ] **Step 5:** Commit `feat(front/serialization): silhouette on the wire, strict + byte-stable (#F)` + AI_HISTORY.

### Task 3: `ArrowBoard.remountedOn(BoardSpace)`

**Files:**
- Modify: `lib/domain/arrows/entities/arrow_board.dart`
- Test: `test/domain/entities/arrow_board_remount_test.dart` (nuevo)

**Interfaces:**
- Produces: `ArrowBoard remountedOn(BoardSpace space)` — mismo contenido de flechas, espacio nuevo; los invariantes del constructor de `ArrowBoard` se re-ejecutan (celda fuera del espacio nuevo ⇒ excepción de dominio existente).

- [ ] **Step 1: Tests (subagente):** remount de un board 4×4 a `MaskedSpace` que contiene todas las flechas → mismo `arrows`, `space` nuevo; remount a espacio que EXCLUYE una celda de una flecha → lanza la excepción de dominio del constructor; remount preserva igualdad de flechas (`Equatable`).
- [ ] **Step 2:** FAIL → **Step 3:** implementar (constructor principal de `ArrowBoard` con las mismas flechas y el espacio dado; método de una línea documentado como seam de montaje). **Step 4:** PASS + analyze. **Step 5:** Commit `feat(front/domain): ArrowBoard.remountedOn as mounting seam (#F)` + AI_HISTORY.

### Task 4: `_mountedBoard` monta `MaskedSpace` desde la silueta

**Files:**
- Modify: `lib/application/state/game_controller.dart:131-142`
- Test: `test/application/state/game_controller_themed_space_test.dart` (reescribir asserts), `test/presentation/game/widgets/board_view_themed_full_box_test.dart` → renombrar a `board_view_themed_masked_test.dart`

**Interfaces:**
- Consumes: `Level.silhouetteUnion` (Task 1), `ArrowBoard.remountedOn` (Task 3), `MaskedSpace(cols, rows, {required activeCells})` (existente).

- [ ] **Step 1: Tests (subagente):** controller — nivel con silhouette monta `MaskedSpace` con `activeCells == silhouetteUnion` (assert de tipo e igualdad de espacio); nivel sin silhouette (campaña) sigue montando `RectSpace` idéntico al wire; `undoMove` y restart reconstruyen el mismo `MaskedSpace`. Widget — `BoardView` con estado temático enmascarado: tap en celda fuera de la silueta NO dispara `onTapArrow`; painter pinta solo celdas activas (reutilizar el patrón `paintsExactlyCountTimes(#drawRect, N)` de `board_view_masked_space_test.dart`).
- [ ] **Step 2:** FAIL → **Step 3:** reemplazar la identidad por:

```dart
// Montaje (front#F): un nivel con silueta se juega sobre el MaskedSpace de su
// figura — fuera de la silueta no hay tablero (spec 2026-07-16). Campaña y
// niveles sin silueta conservan su RectSpace del wire. Revierte la decisión
// "caja completa" de front#99/#107 SOLO para temáticos con silueta.
ArrowBoard _mountedBoard(Level level) {
  final active = level.silhouetteUnion;
  if (active == null) return level.board;
  final box = level.board.space.bounds;
  return level.board.remountedOn(
    MaskedSpace(box.cols, box.rows, activeCells: active),
  );
}
```
- [ ] **Step 4:** `flutter test` COMPLETO (no solo los tocados: el cambio de montaje puede afectar goldens/painter) → PASS; analyze limpio.
- [ ] **Step 5:** Commit `feat(front/state): mount themed levels on their silhouette MaskedSpace (#F)` + AI_HISTORY + README (sección de niveles temáticos).

---

## FASE B — Front: generador denso + máscaras + fixtures

### Task 5: Modo denso del generador temático

**Files:**
- Modify: `lib/infrastructure/generators/graph_board_generator.dart`
- Test: `test/infrastructure/generators/graph_board_themed_dense_test.dart` (nuevo)

**Interfaces:**
- Consumes: `generateThemed` existente (invariante DAG: una flecha solo se coloca si su `exitLane` está libre en ese momento; `occupied` global).
- Produces: `ArrowBoard generateThemedDense({required int cols, required int rows, required List<ThemedRegionSpec> regions, int? seed, int gapFillMaxLen = 3, double bendBias = 0.7})`.

**Algoritmo (mismo invariante DAG, tres refuerzos):**
1. **Interior-first:** dentro de cada región, ordenar las celdas candidatas a cabeza por distancia-al-borde-de-la-región descendente (BFS multi-source desde las celdas frontera de la región); se intenta cubrir primero el centro, cuando más carriles libres hay.
2. **Sesgo a codos:** al crecer el cuerpo hacia atrás (random walk auto-evitante existente), con probabilidad `bendBias` preferir un vecino que cambie de dirección respecto al último paso, si existe; los guardianes de variedad se apoyan en esto.
3. **Pasadas de relleno:** tras la pasada principal, mientras queden celdas libres en la región: intentar colocar flechas de longitud `gapFillMaxLen`→2 con cabeza en cada celda libre (mismo requisito de carril libre). Repetir hasta pasada sin progreso.
La solvencia se conserva por construcción (el invariante no se toca). Nota para el implementador: el carril se evalúa sobre el `RectSpace` interno completo; al montarse en juego sobre `MaskedSpace` los carriles son sub-conjuntos (terminan antes, en la frontera de la máscara), así que carril-libre en generación ⟹ carril-libre en juego.

- [ ] **Step 1: Tests guardianes (subagente, sobre máscaras reales `heart` 36×24 de Task 6 y `happy_face`; usar seeds fijas):**
  - **Densidad:** cobertura global ≥0.90 y cada región de detalle al 100% (probar con la mejor seed de `0..99`).
  - **Variedad:** ≥40% de flechas con ≥1 codo (codo = cambio de dirección entre celdas consecutivas del cuerpo).
  - **Anti-columnas:** ninguna terna de flechas rectas paralelas adyacentes (tres flechas rectas de la misma dirección en filas/columnas contiguas con cuerpos solapados en proyección).
  - **Huecos al borde:** distancia media de las celdas libres al borde de su región ≤ 1.5 (umbral calibrable; se fija aquí y se documenta).
  - **Solvencia:** `validateCandidate(board)` no lanza (reutilizar `tool/level_production/validation.dart`).
  - **Determinismo:** misma seed ⇒ mismo board.
- [ ] **Step 2:** FAIL → **Step 3:** implementar `generateThemedDense` reutilizando los helpers privados existentes (`_freeNeighbors`, `_randomHeadWithClearLane`, pool de cuerpos); factorizar lo compartido con `generateThemed` sin cambiar su comportamiento (sus tests actuales quedan verdes).
- [ ] **Step 4:** `flutter test test/infrastructure/generators/` completo → PASS (incluye los tests previos del generador, densidad, perf). Analyze limpio.
- [ ] **Step 5:** Commit `feat(front/generators): dense themed fill — interior-first, bend bias, gap-fill passes (#F)` + AI_HISTORY.

### Task 6: Máscara del corazón a 36×24

**Files:**
- Create: `tool/level_production/masks/heart.mask` (reemplaza el 24×16)
- Test: `test/tool/level_production/mask_spec_test.dart` (extender)

- [ ] **Step 1:** Generar el grid 36×24 con un script one-off (escala ×1.5 nearest-neighbor del heart 24×16 actual + suavizado manual de escalones): en el scratchpad, leer `heart.mask` actual, mapear cada celda destino `(r,c)` → fuente `(r*16/24, c*24/36)`, emitir glyphs. Revisar el resultado A OJO en el preview (paso 3) y retocar filas a mano si hay escalones feos (el lóbulo superior y la punta inferior son los delicados).
- [ ] **Step 2:** Reemplazar el bloque `grid:` de `heart.mask` (cabecera y leyenda `H = heart : #FF4D6D` intactas).
- [ ] **Step 3:** Validar: `parseMaskSpec` no lanza; dims 36×24; test nuevo en `mask_spec_test.dart` que congela dims y `cellCount` del corazón (caracterización de la máscara). Generar preview con el producer (Task 7 step 3) y confirmar la forma visualmente ANTES de commitear.
- [ ] **Step 4:** Commit `feat(front/tooling): heart mask at 36x24 (#F)` + AI_HISTORY.

### Task 7: Producer denso + regeneración de fixtures (+ conejo congelado)

**Files:**
- Modify: `tool/level_production/themed_producer.dart`, `tool/level_production/produce_themed.dart`
- Create: `tool/level_production/add_silhouette.dart` (one-off para el conejo)
- Modify (regenerados): `tool/level_production/themed/themed-heart.json|.preview.txt`, `themed-happy_face.json|.preview.txt`, `themed-bunny.json` (solo clave nueva), `manifest-themed.md`
- Test: `test/tool/level_production/themed_producer_test.dart` (extender) + `test/tool/level_production/themed_bunny_characterization_test.dart` (nuevo)

**Interfaces:**
- Consumes: `generateThemedDense` (Task 5), encoder con `silhouette` (Task 2), `MaskSpec.regions` (existente: rol → celdas).
- Produces: fixtures con `silhouette = {region.role: region.cells}` (el fill completo de la máscara, no la unión de flechas).

- [ ] **Step 1: Tests (subagente):** producer usa `generateThemedDense` y emite `silhouette` desde `mask.regions`; el JSON producido decodifica a un `Level` válido (invariante flechas⊆silueta pasa); cobertura reportada en `ThemedResult` ≥0.90 para heart/happy_face con seeds del lote; **caracterización del conejo**: `themed-bunny.json` decodifica, tiene exactamente las 37 flechas actuales (congelar ids+celdas por hash o lista) y `silhouette` == regiones de `bunny.mask`.
- [ ] **Step 2:** FAIL → **Step 3:** cablear `themed_producer.dart` a `generateThemedDense` (flag CLI `--dense` default true, `--coverage` default 0.90) y pasar `silhouette` al encoder. Escribir `add_silhouette.dart`: decodifica `themed-bunny.json`, re-encodea con `silhouette` de `bunny.mask` (flechas intactas, byte-estable).
- [ ] **Step 4:** Regenerar: `dart run tool/level_production/produce_themed.dart --masks-dir tool/level_production/masks --out tool/level_production/themed --coverage 0.90 --seeds 0..99` para heart y happy_face; `dart run tool/level_production/add_silhouette.dart` para bunny. **Verificar los `.preview.txt` a ojo** (¿se lee la figura? ¿huecos al borde y no en el centro de la cara?) y pegar los previews en el PR. Si happy_face no alcanza 0.90 en 100 seeds, ampliar seeds o ajustar `gapFillMaxLen`; si una celda de detalle queda irrellenable, retocar la máscara (constraint global) y regenerar.
- [ ] **Step 5:** `flutter test` completo → PASS. Commit `feat(front/tooling): dense themed production + silhouette in fixtures; bunny frozen (#F)` + AI_HISTORY + README (tooling).

---

## FASE C — Back: silhouette en el wire

### Task 8: Dominio back — `LevelSilhouette` opaco

**Files:**
- Modify: `src/domain/entities/level.entity.ts`, `src/domain/entities/level.builder.ts`
- Test: `src/domain/entities/level.entity.spec.ts`, `level.builder.spec.ts` (extender)

**Interfaces:**
- Produces: `export type LevelSilhouette = Readonly<Record<string, ReadonlyArray<readonly [number, number]>>>;` — 7º parámetro opcional del constructor de `Level` (tras `paint`), portador opaco SIN validación en el constructor (mismo trato que `paint`). `LevelBuilder.withSilhouette(silhouette?: LevelSilhouette): this`.

- [ ] **Step 1: Tests (subagente):** `Level` con silhouette la expone tal cual y no altera invariantes; sin silhouette ⇒ `undefined`; builder `withSilhouette` passthrough hasta `build()` (espejo de los specs de `withPaint`).
- [ ] **Step 2:** FAIL → **Step 3:** implementar (type + param opcional + campo builder + propagación en `build()`). **Step 4:** `npm test` verde. **Step 5:** Commit `feat(back/domain): opaque LevelSilhouette carrier on Level + builder (#B)` + AI_HISTORY.

### Task 9: Validador + seed

**Files:**
- Create: `src/infrastructure/database/level-silhouette.validator.ts`
- Modify: `prisma/seed.ts`
- Test: `src/infrastructure/database/level-silhouette.validator.spec.ts` (nuevo)

**Interfaces:**
- Consumes: patrón de `level-paint.validator.ts` (`PaintFixtureShape`, lanza `Error` a la primera violación).
- Produces: `export function validateLevelSilhouette(fixture: SilhouetteFixtureShape): void` con reglas: si `silhouette` ausente ⇒ ok (campaña); presente ⇒ objeto no vacío, cada rol referencia una clave de `palette`, cada celda es par entero `[row,col]` dentro de `cols×rows`, sin duplicados intra-región, sin solape entre regiones, y **toda celda de toda flecha ∈ unión de la silueta**.

- [ ] **Step 1: Tests (subagente):** un caso por regla (válido, ausente, mapa vacío, rol sin palette, celda no entera, fuera de rango, duplicada, solapada entre regiones, flecha fuera de la unión) — espejo AAA de `level-paint.validator.spec.ts`.
- [ ] **Step 2:** FAIL → **Step 3:** implementar validator; en `prisma/seed.ts`: añadir `silhouette?: Record<string, number[][]>` a `LevelFixture`, llamar `validateLevelSilhouette(fixture)` en `validate()` tras `validateLevelPaint`, y spread condicional en `toData()` (`...(fixture.silhouette !== undefined ? { silhouette: fixture.silhouette } : {})`).
- [ ] **Step 4:** `npm test` verde. **Step 5:** Commit `feat(back/db): validate and persist themed silhouette in seed (#B)` + AI_HISTORY.

### Task 10: Read-path — repo, mapper, e2e

**Files:**
- Modify: `src/infrastructure/database/prisma-level.repository.ts`, `src/adapters/mappers/level.mapper.ts`, `src/adapters/controllers/level.controller.ts` (solo docs Swagger)
- Test: `prisma-level.repository.spec.ts`, `level.mapper.spec.ts`, `test/levels-themed.e2e-spec.ts` (extender)

**Interfaces:**
- Consumes: `LevelSilhouette` (Task 8); `LevelDataPrimitives` del repo.
- Produces: `LevelResponseDto.silhouette?: Record<string, number[][]>` en `GET /levels/:id` (el summary de `GET /levels` NO cambia).

- [ ] **Step 1: Tests (subagente):** repo — `toDomain` iza `data.silhouette` a `level.silhouette` (y `undefined` si ausente); mapper — `toDto` emite `silhouette` con spread condicional (espejo del caso palette) y round-trip por igualdad profunda; e2e — en `levels-themed.e2e-spec.ts`, el fixture in-memory gana `silhouette` y `GET /levels/:id` la devuelve byte-a-byte; `GET /levels` sigue sin ella.
- [ ] **Step 2:** FAIL → **Step 3:** implementar: `LevelDataPrimitives.silhouette?`, `.withSilhouette(data.silhouette)` en `toDomain`, spread en `toDto`, ampliar descripción `@ApiOperation` del detalle mencionando `silhouette`.
- [ ] **Step 4:** `npm test` + `npm run test:e2e` verdes. **Step 5:** Commit `feat(back/read-path): serve themed silhouette through repo and mapper (#B)` + AI_HISTORY + README back (contrato del endpoint).

### Task 11: Seeds del back regenerados

**Files:**
- Modify: `prisma/levels/t-heart.json`, `t-happy-face.json`, `t-bunny.json`, `prisma/levels/manifest.md`
- Test: `src/infrastructure/database/curated-levels.spec.ts` (extender)

**Interfaces:**
- Consumes: fixtures del front (Task 7). Transformación front→back por archivo: `levelId` `themed-<name>` → `t-<name>` (guion en `happy_face` → `happy-face`), añadir `"section": "themed"`, resto idéntico (cols/rows/palette/arrows/silhouette).

- [ ] **Step 1: Tests (subagente) en `curated-levels.spec.ts` (describe 'themed fixtures'):** los 3 temáticos tienen `silhouette`; `validateLevelSilhouette(fixture)` no lanza; cobertura de flechas sobre la unión ≥0.90 para t-heart/t-happy-face (guardián de densidad TAMBIÉN en el back, sobre los datos reales); t-bunny conserva exactamente 37 flechas; solvencia (`solver.isSolvable`) para los 3; campaña sigue sin `silhouette`.
- [ ] **Step 2:** FAIL → **Step 3:** copiar/transformar los 3 fixtures desde el front (script one-off o edición directa; documentar en manifest.md la regeneración densa + silhouette, preservando la sección de campaña #52 intacta).
- [ ] **Step 4:** Suite completa back verde (`lint:check`, `test`, `test:e2e`, `build`). **Step 5:** Commit `feat(back/db): dense themed seeds with silhouette; bunny arrows frozen (#B)` + AI_HISTORY.

---

## FASE D — Integración y cierre

### Task 12: Verificación end-to-end + PRs

- [ ] **Step 1:** Front: `flutter analyze` + `flutter test` completos. Back: `npm run lint:check && npm test && npm run test:e2e && npm run build`.
- [ ] **Step 2:** Docker: levantar el back de la rama (`docker compose up`), `npx prisma migrate reset` (reseed), y verificar con `curl` que `GET /levels/t-heart` devuelve `silhouette` + 48± flechas y que `GET /levels` lista los 3 temáticos. Correr el front de la rama contra ese API y **capturar pantalla de los 3 temáticos** (silueta enmascarada, sin tablero fuera, sin huecos centrales) para el PR.
- [ ] **Step 3:** Abrir PR front (`Closes #F`, con capturas y previews) y PR back (`Closes #B`, referencia cruzada). Ambos con resumen del spec y nota "supersedes #115/#51". El maintainer decide merges y cierre de los PRs viejos.

---

## Self-review del plan (hecho)

- Cobertura del spec: §3 wire → Tasks 2/8/9/10/11; §4 render → Tasks 3/4 (painter/hit-test ya existen, verificados por tests de Task 4); §5 generador+guardianes → Task 5 (tabla completa); §6 máscaras/fixtures → Tasks 6/7/11; §7 testing → distribuido por tarea; §8 ejecución → Tasks 0/12.
- Tipos consistentes: front `Map<String, Set<Position>>?` en dominio ↔ wire `Record<string, number[][]>`; back `LevelSilhouette` opaco (espejo de `LevelPaint`).
- El orden de las tareas permite front A (1-4) contra JSON inline sin esperar tooling ni back.
