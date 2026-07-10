# front#1 — Script generador de candidatos de nivel (seeds fijas) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tooling reproducible que corre `GraphBoardGenerator` con una tabla fija de seeds y congela ~30 candidatos de nivel como JSON arrow-path wire-estricto (insumo de la curación E2.2; desbloquea back#10).

**Architecture:** Un `LevelJsonEncoder` en `lib/infrastructure/serialization/` (mapea `ArrowBoard` → wire contract, testeable) y un CLI fino en `tool/generate_level_candidates.dart` (tabla `batchSpec` fija + IO). La salida se commitea en `tool/candidates/` porque `Random(seed)` de Dart no garantiza estabilidad entre versiones del SDK: el artefacto congelado real es el JSON en git, no la seed.

**Tech Stack:** Dart puro (el script corre con `dart run`, sin arrancar Flutter), `dart:convert`, `dart:io` (solo en `tool/`), flutter_test para los tests.

## Global Constraints

- **Issue:** MazePruebaFront#1 `chore(tooling): level generator script with fixed seeds` (= E2.1 del backlog de cutover).
- **Repo/rama:** trabajar en `MazePruebaFront/` sobre rama nueva `chore/front1-level-candidates` desde `main`. **NO abrir PR** hasta que la feature esté completa (los 3 fragmentos commiteados); la apertura del PR se confirma con el usuario.
- **Wire contract (CONTEXT-MAP.md raíz, canónico):** `{levelId, cols, rows, timeLimitSec?, arrows:[{id, headDir, cells:[[row,col],…]}]}`. `cells` va de cola (índice 0) a cabeza (último); `headDir` ∈ `up|down|left|right`. Los candidatos **omiten** `timeLimitSec` (lo decide la curación). Ninguna clave extra: el JSON debe ser copiable tal cual al seed Prisma (back#10).
- **Arquitectura por capas:** `lib/infrastructure/` puede importar `lib/domain/`; nada de `lib/presentation/` ni Flutter en la cadena que usa el script. `tool/` importa `package:flutter_arrow_maze/...`.
- **`levelId` de candidato es `String` plano** (`cand-t<tier>-s<seed>`), NO el VO `LevelId` (ese VO asume ids numéricos vía `number`; tensión conocida con el wire `l-007`, pertenece a E1.3, fuera de alcance aquí).
- **Ids de flecha:** se serializan tal cual los emite el generador (`arrow-0`, `arrow-1`, …); son opacos según el contrato.
- **Degradación:** si el generador coloca menos flechas de las pedidas, el candidato se exporta igual y el manifiesto registra `colocadas/pedidas` con marca `(!)`.
- **Tests:** patrón AAA, nombres `should_..._when_...`, sin mocks (todo es puro). Las tareas de test se delegan a un subagente QA con el prompt incluido en cada tarea (convención del proyecto: los planes no llevan código de test inline).
- **DoD:** `flutter analyze` limpio, `flutter test` verde, Conventional Commit por fragmento, entrada en `AI_HISTORY.MD` por fragmento, README actualizado (el script es API pública del artefacto).
- **Comentarios en código:** en español, explicando qué problema resuelve (estilo del repo). Sin `print`/logger en lógica de negocio; el script de `tool/` sí usa `stdout` (es CLI, no negocio).

---

### Task 1: `LevelJsonEncoder` (fragmento 1)

**Files:**
- Create: `lib/infrastructure/serialization/level_json_encoder.dart`
- Test: `test/infrastructure/serialization/level_json_encoder_test.dart` (vía subagente QA)

**Interfaces:**
- Consumes: `ArrowBoard` (`lib/domain/arrows/entities/arrow_board.dart`: `.arrows`, `.cols`, `.rows`), `Arrow` (`.id.value`, `.headDirection.name`, `.cells`), `Position` (`.row`, `.col`).
- Produces: `class LevelJsonEncoder { const LevelJsonEncoder(); Map<String, Object?> toMap({required String levelId, required ArrowBoard board, int? timeLimitSec}); String encode({required String levelId, required ArrowBoard board, int? timeLimitSec}); }` — Task 2 depende de `encode` exactamente con esa firma.

- [ ] **Step 1: Crear la rama de trabajo**

```bash
cd MazePruebaFront
git checkout main && git pull
git checkout -b chore/front1-level-candidates
```

- [ ] **Step 2: Delegar los tests del encoder al subagente QA (deben fallar: la clase no existe)**

Prompt para el subagente (rol `qa-engineer`, skill `arrowmaze-qa`):

> Escribe `test/infrastructure/serialization/level_json_encoder_test.dart` en `MazePruebaFront/` (package `flutter_arrow_maze`) para una clase AÚN NO CREADA `LevelJsonEncoder` en `lib/infrastructure/serialization/level_json_encoder.dart` con API: `const LevelJsonEncoder()`, `Map<String, Object?> toMap({required String levelId, required ArrowBoard board, int? timeLimitSec})` y `String encode({...misma firma})`. Serializa al wire contract arrow-path: `{levelId, cols, rows, timeLimitSec?, arrows:[{id, headDir, cells:[[row,col],…]}]}`.
> Patrón AAA estricto, nombres `should_..._when_...`, sin mocks (construye `ArrowBoard`/`Arrow` reales; `Arrow` requiere `ArrowId`, `List<Position>` cola→cabeza y `Direction`). Casos mínimos:
> 1. `should_serialize_wire_contract_keys_when_encoding_board` — `toMap` produce exactamente las claves `levelId`, `cols`, `rows`, `arrows` (sin `timeLimitSec` si es null) con los valores del board.
> 2. `should_serialize_cells_tail_to_head_as_row_col_pairs_when_arrow_is_bent` — una flecha doblada (p.ej. cells `[(10,3),(9,3),(9,4)]`, headDir up) produce `"cells": [[10,3],[9,3],[9,4]]` en ese orden.
> 3. `should_map_head_direction_to_wire_string_when_encoding` — las 4 direcciones producen `"up"|"down"|"left"|"right"`.
> 4. `should_omit_time_limit_sec_when_null` y `should_include_time_limit_sec_when_provided`.
> 5. `should_serialize_empty_arrows_list_when_board_is_cleared` — board sin flechas → `"arrows": []`.
> 6. `should_end_with_newline_and_two_space_indent_when_encode_returns_string` — `encode` devuelve JSON con indent de 2 espacios (`JsonEncoder.withIndent('  ')`) y termina en `\n`.
> No crees la clase de producción. Entrega solo el archivo de test.

- [ ] **Step 3: Verificar que los tests fallan**

Run: `flutter test test/infrastructure/serialization/level_json_encoder_test.dart`
Expected: FAIL (error de compilación: `level_json_encoder.dart` no existe).

- [ ] **Step 4: Implementar el encoder**

```dart
// lib/infrastructure/serialization/level_json_encoder.dart
import 'dart:convert';

import '../../domain/arrows/entities/arrow_board.dart';

/// Serializa un [ArrowBoard] al JSON arrow-path del wire contract
/// (CONTEXT-MAP raíz). Emite EXACTAMENTE las claves del contrato para que el
/// JSON sea copiable tal cual al seed del back sin limpiar campos.
class LevelJsonEncoder {
  const LevelJsonEncoder();

  Map<String, Object?> toMap({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
  }) =>
      {
        'levelId': levelId,
        'cols': board.cols,
        'rows': board.rows,
        if (timeLimitSec != null) 'timeLimitSec': timeLimitSec,
        'arrows': [
          for (final a in board.arrows)
            {
              'id': a.id.value,
              'headDir': a.headDirection.name,
              'cells': [
                for (final c in a.cells) [c.row, c.col],
              ],
            },
        ],
      };

  /// JSON con indent de 2 espacios y newline final: salida byte-estable para
  /// congelar candidatos en git (mismo input => mismos bytes).
  String encode({
    required String levelId,
    required ArrowBoard board,
    int? timeLimitSec,
  }) =>
      '${const JsonEncoder.withIndent('  ').convert(toMap(levelId: levelId, board: board, timeLimitSec: timeLimitSec))}\n';
}
```

- [ ] **Step 5: Verificar tests verdes y analyze limpio**

Run: `flutter test test/infrastructure/serialization/level_json_encoder_test.dart && flutter analyze`
Expected: PASS todos los tests; analyze sin issues nuevos (hay deuda de lint baseline conocida en el repo — no introducir issues nuevos).

- [ ] **Step 6: Registrar entrada en AI_HISTORY.MD**

Localizar el último número: `grep -o "^## Entrada [0-9]*" AI_HISTORY.MD | tail -1`, usar NNN+1 y la plantilla del proyecto (Fecha 2026-07-09, tarea: fragmento 1 de front#1, herramienta: Claude Code, prompt: cita breve del encargo, resultado: `LevelJsonEncoder` + tests).

- [ ] **Step 7: Commit del fragmento 1**

```bash
git add lib/infrastructure/serialization/level_json_encoder.dart test/infrastructure/serialization/level_json_encoder_test.dart AI_HISTORY.MD
git commit -m "feat(infra): add LevelJsonEncoder for arrow-path wire format"
```

---

### Task 2: Script `tool/generate_level_candidates.dart` + docs (fragmento 2)

**Files:**
- Create: `tool/generate_level_candidates.dart`
- Test: `test/infrastructure/serialization/level_generation_determinism_test.dart` (vía subagente QA)
- Modify: `README.md` (nueva sección Tooling), `CONTEXT.md` (glosario: Producción de niveles)

**Interfaces:**
- Consumes: `GraphBoardGenerator().generate({required int cols, required int rows, required int arrowCount, required int maxPathLen, int? seed})` → `ArrowBoard`; `LevelJsonEncoder.encode(...)` de Task 1.
- Produces: comando `dart run tool/generate_level_candidates.dart [--out <dir>]` que escribe `<levelId>.json` × 30 + `manifest.md` en `tool/candidates/` (default). Task 3 depende de este comando.

- [ ] **Step 1: Delegar el test de determinismo al subagente QA (cubre el AC "misma seed → mismo JSON")**

Prompt para el subagente (rol `qa-engineer`, skill `arrowmaze-qa`):

> Escribe `test/infrastructure/serialization/level_generation_determinism_test.dart` en `MazePruebaFront/` (package `flutter_arrow_maze`). Cubre el criterio de aceptación de front#1 "script reproducible: misma seed → mismo JSON" a nivel de las piezas que usa el script (sin importar `tool/`): `GraphBoardGenerator` (`lib/infrastructure/generators/graph_board_generator.dart`) + `LevelJsonEncoder` (Task 1, ya existe). AAA, `should_..._when_...`, sin mocks. Casos:
> 1. `should_produce_identical_json_when_generating_twice_with_same_seed` — dos invocaciones de `GraphBoardGenerator().generate(cols: 8, rows: 11, arrowCount: 9, maxPathLen: 5, seed: 302)` encodeadas con `LevelJsonEncoder().encode(levelId: 'cand-t3-s302', board: ...)` producen strings idénticos (`==` byte a byte).
> 2. `should_produce_different_json_when_seeds_differ` — seeds 1 y 2 (mismos demás parámetros) producen strings distintos.
> Ambos tests ya deben pasar (el comportamiento existe); si alguno falla, repórtalo como hallazgo en vez de ajustar el test.

Run: `flutter test test/infrastructure/serialization/level_generation_determinism_test.dart`
Expected: PASS (el determinismo ya existe en el generador; este test lo fija como contrato).

- [ ] **Step 2: Implementar el script**

```dart
// tool/generate_level_candidates.dart
//
// E2.1 (front#1): corre GraphBoardGenerator con una tabla FIJA de seeds y
// congela candidatos de nivel como JSON arrow-path wire-estricto, insumo de
// la curación E2.2 (elegir 3 por tier => 15 niveles). Sin argumentos produce
// SIEMPRE el mismo set completo; la reproducibilidad vive en esta tabla
// versionada, y el artefacto congelado real son los JSON commiteados
// (Random(seed) de Dart no garantiza estabilidad entre versiones del SDK).
//
// Uso: dart run tool/generate_level_candidates.dart [--out <dir>]
import 'dart:io';

import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_encoder.dart';

class CandidateSpec {
  final int tier;
  final int cols;
  final int rows;
  final int arrowCount;
  final int maxPathLen;
  final int seed;

  const CandidateSpec({
    required this.tier,
    required this.cols,
    required this.rows,
    required this.arrowCount,
    required this.maxPathLen,
    required this.seed,
  });

  /// Identidad trazable del candidato: tier + seed bastan para reproducirlo.
  String get levelId => 'cand-t$tier-s$seed';
}

// Rampa de dificultad: 5 tiers x 6 candidatos = 30 (2x oversupply: la
// curacion elige 3 por tier). Dims en vertical (cols < rows, como el wire).
const _batchSpec = <CandidateSpec>[
  // Tier 1 — 6x8, maxPathLen 4
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 101),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 102),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 5, maxPathLen: 4, seed: 103),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 104),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 105),
  CandidateSpec(tier: 1, cols: 6, rows: 8, arrowCount: 6, maxPathLen: 4, seed: 106),
  // Tier 2 — 7x10, maxPathLen 5
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 7, maxPathLen: 5, seed: 201),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 7, maxPathLen: 5, seed: 202),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 7, maxPathLen: 5, seed: 203),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 8, maxPathLen: 5, seed: 204),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 8, maxPathLen: 5, seed: 205),
  CandidateSpec(tier: 2, cols: 7, rows: 10, arrowCount: 8, maxPathLen: 5, seed: 206),
  // Tier 3 — 8x11, maxPathLen 5
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 9, maxPathLen: 5, seed: 301),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 9, maxPathLen: 5, seed: 302),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 10, maxPathLen: 5, seed: 303),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 10, maxPathLen: 5, seed: 304),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 11, maxPathLen: 5, seed: 305),
  CandidateSpec(tier: 3, cols: 8, rows: 11, arrowCount: 11, maxPathLen: 5, seed: 306),
  // Tier 4 — 9x13, maxPathLen 6
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 12, maxPathLen: 6, seed: 401),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 12, maxPathLen: 6, seed: 402),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 13, maxPathLen: 6, seed: 403),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 13, maxPathLen: 6, seed: 404),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 14, maxPathLen: 6, seed: 405),
  CandidateSpec(tier: 4, cols: 9, rows: 13, arrowCount: 14, maxPathLen: 6, seed: 406),
  // Tier 5 — 11x15, maxPathLen 7
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 15, maxPathLen: 7, seed: 501),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 15, maxPathLen: 7, seed: 502),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 16, maxPathLen: 7, seed: 503),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 16, maxPathLen: 7, seed: 504),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 18, maxPathLen: 7, seed: 505),
  CandidateSpec(tier: 5, cols: 11, rows: 15, arrowCount: 18, maxPathLen: 7, seed: 506),
];

const _manifestHeader = '''
# Candidatos de nivel — batch v1

Generado por `dart run tool/generate_level_candidates.dart` (tabla fija de seeds).
Insumo de la curación E2.2: elegir 3 por tier => 15 niveles (ver CONTEXT-MAP, wire contract).
NO editar a mano: regenerar con el script (misma tabla => mismos bytes).
`(!)` = degradación con gracia: el generador coloco menos flechas de las pedidas.

| candidato | dims (cols x rows) | flechas (colocadas/pedidas) | maxPathLen | seed |
|---|---|---|---|---|
''';

void main(List<String> args) {
  final outPath = _parseOut(args) ?? 'tool/candidates';
  final outDir = Directory(outPath)..createSync(recursive: true);

  final generator = GraphBoardGenerator();
  const encoder = LevelJsonEncoder();
  final manifest = StringBuffer(_manifestHeader);
  var degraded = 0;

  for (final spec in _batchSpec) {
    final board = generator.generate(
      cols: spec.cols,
      rows: spec.rows,
      arrowCount: spec.arrowCount,
      maxPathLen: spec.maxPathLen,
      seed: spec.seed,
    );
    File('${outDir.path}/${spec.levelId}.json')
        .writeAsStringSync(encoder.encode(levelId: spec.levelId, board: board));

    final placed = board.arrows.length;
    final flag = placed < spec.arrowCount ? ' (!)' : '';
    if (placed < spec.arrowCount) degraded++;
    manifest.writeln(
        '| ${spec.levelId} | ${spec.cols}x${spec.rows} | $placed/${spec.arrowCount}$flag | ${spec.maxPathLen} | ${spec.seed} |');
  }

  File('${outDir.path}/manifest.md').writeAsStringSync(manifest.toString());
  stdout.writeln(
      'Exported ${_batchSpec.length} candidates to ${outDir.path} ($degraded degraded).');
}

String? _parseOut(List<String> args) {
  final i = args.indexOf('--out');
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}
```

- [ ] **Step 3: Smoke run del script**

Run: `dart run tool/generate_level_candidates.dart --out build/candidates-smoke`
Expected: `Exported 30 candidates to build/candidates-smoke (N degraded).` con N ≥ 0; 30 `.json` + `manifest.md` en la carpeta. Inspeccionar 1 JSON: claves exactas del wire contract. Borrar la carpeta smoke después (`build/` no se commitea).

- [ ] **Step 4: README — sección Tooling**

Añadir a `README.md` (tras la sección de arquitectura):

```markdown
## Tooling

### Generador de candidatos de nivel (front#1 / E2.1)

    dart run tool/generate_level_candidates.dart [--out <dir>]

Corre `GraphBoardGenerator` con la tabla fija de seeds de
`tool/generate_level_candidates.dart` y escribe en `tool/candidates/` (default)
un JSON wire-estricto por candidato (`{levelId, cols, rows, arrows[]}`, ver
CONTEXT-MAP raíz) más `manifest.md` con la tabla del batch. Reproducible:
misma tabla => mismos archivos. Los candidatos commiteados son el artefacto
congelado que consume la curación (E2.2) y el seed del back (back#10);
cambiar el batch = editar la tabla y commitear la regeneración.
```

- [ ] **Step 5: CONTEXT.md — glosario de producción de niveles**

Añadir al final de la sección `## Language` de `CONTEXT.md`:

```markdown
### Producción de niveles

**Candidato (de nivel)**:
Tablero soluble generado con seed fija y exportado como JSON arrow-path, identificado de
forma trazable por su tier y seed (`cand-t3-s302`). Es insumo de la Curación; **no** es un
nivel jugable servido hasta ser curado y congelado en la API.
_Avoid_: nivel provisional, nivel random, borrador jugable.

**Curación**:
Selección manual de 15 Candidatos (3 por Tier) que se congelan como los niveles oficiales
que sirve la API. El orden y `timeLimitSec` los decide la curación, no el generador.
_Avoid_: generación, sorteo, autogenerado.

**Tier (de dificultad)**:
Cada uno de los 5 escalones de la rampa (dimensiones, cantidad de flechas y longitud máxima
de camino crecientes) en que se agrupan Candidatos y niveles curados.
_Avoid_: mundo, capítulo.
```

- [ ] **Step 6: Verificación del fragmento**

Run: `flutter analyze && flutter test`
Expected: analyze sin issues nuevos; suite completa verde.

- [ ] **Step 7: AI_HISTORY + commit del fragmento 2**

Entrada AI_HISTORY (NNN+1, fragmento 2: script + docs). Luego:

```bash
git add tool/generate_level_candidates.dart test/infrastructure/serialization/level_generation_determinism_test.dart README.md CONTEXT.md AI_HISTORY.MD
git commit -m "chore(tooling): add level candidate generator script with fixed seeds"
```

---

### Task 3: Congelar los candidatos (fragmento 3)

**Files:**
- Create: `tool/candidates/manifest.md` + `tool/candidates/cand-t*.json` × 30 (generados, no escritos a mano)

**Interfaces:**
- Consumes: comando de Task 2.
- Produces: los archivos congelados que consumen E2.2 (curación) y back#10 (seed Prisma).

- [ ] **Step 1: Generar el batch definitivo**

Run: `dart run tool/generate_level_candidates.dart`
Expected: `Exported 30 candidates to tool/candidates (N degraded).`

- [ ] **Step 2: Verificar reproducibilidad (AC del issue)**

Volver a correr el mismo comando y comprobar que no cambia ningún byte:

```bash
dart run tool/generate_level_candidates.dart
git status --short tool/candidates
```

Expected: la segunda corrida no modifica nada (`git status` sin salida tras el primer `git add`, o `git diff` vacío si ya estaban trackeados). Nota Windows: si aparecen diffs fantasma de fin de línea, es `core.autocrlf` — los archivos se escriben con LF; no "arreglar" convirtiendo a CRLF.

- [ ] **Step 3: Revisión rápida del manifiesto**

Abrir `tool/candidates/manifest.md`: 30 filas, 6 por tier; anotar cuántos `(!)` (degradados) hay. Si un tier entero saliera degradado (improbable), reportarlo al usuario antes de commitear — la tabla de seeds podría necesitar ajuste, pero eso es decisión del usuario, no del ejecutor.

- [ ] **Step 4: AI_HISTORY + commit del fragmento 3**

Entrada AI_HISTORY (NNN+2, fragmento 3: batch v1 congelado, resumen del manifiesto). Luego:

```bash
git add tool/candidates AI_HISTORY.MD
git commit -m "chore(levels): freeze 30 level candidates for curation (batch v1)"
```

- [ ] **Step 5: Cierre de feature (sin PR automático)**

Run: `flutter analyze && flutter test` una última vez sobre la rama completa.
Expected: verde. Reportar al usuario: rama `chore/front1-level-candidates` con 3 commits lista; los AC del issue quedan cubiertos (reproducible ✅ test determinismo + re-run sin diff; formato wire ✅ tests encoder; dims variadas ✅ manifiesto 6x8…11x15). **Preguntar al usuario antes de abrir el PR** (main protegido con CI; convención: PR solo con la feature completa).

---

## Self-review (hecho al escribir el plan)

- AC "misma seed → mismo JSON" → Task 2 Step 1 (test) + Task 3 Step 2 (re-run sin diff). AC "formato `{levelId,cols,rows,arrows[]}`" → Task 1 (encoder + tests). AC "dims variadas 6x8…11x15" → tabla de Task 2 + manifiesto.
- Firmas cruzadas verificadas contra el código real: `GraphBoardGenerator.generate` (named params, `seed` opcional), `Arrow.cells` cola→cabeza, `Direction.name`, `Position.row/.col`, `ArrowId.value`.
- `tool/` no se importa desde `test/` (decisión de grilling: el script se valida por re-run + git diff).
