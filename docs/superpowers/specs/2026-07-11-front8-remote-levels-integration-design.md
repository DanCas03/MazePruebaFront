# Spec — front#8: Integración de niveles remotos (campaña servida por el back)

**Fecha:** 2026-07-11
**Issue:** MazePruebaFront#8 (redefinido por el usuario como EL issue de integración back↔front)
**Rama:** `feat/#8-dio-level-dto-mapper`
**Estado:** diseño aprobado por el usuario sección a sección (grilling + brainstorming).
Todas las decisiones están cerradas; este documento es la fuente de verdad para el plan de
implementación (skill `superpowers:writing-plans`).

---

## 1. Objetivo

La campaña del front deja de generar tableros localmente y pasa a jugar los **niveles
oficiales** servidos por `MazePruebaBack` (`GET /levels`, `GET /levels/:id`), de forma
robusta: caché offline, estados de carga/error con retry y "siguiente nivel" dictado por el
orden del Catálogo del back.

**Vocabulario** (glosario `CONTEXT.md`, ya actualizado): **Catálogo (de niveles)** = lista
ordenada de `LevelId` publicada por el back; su orden ES el orden de juego; "siguiente
nivel" = siguiente `LevelId` del Catálogo, nunca aritmética sobre el id.

## 2. Contexto verificado

- back#5 CLOSED: `GET /levels` → `[{ "levelId": string }]` en orden de juego (público);
  `GET /levels/:id` → wire contract completo (público, 404 si no existe):
  `{ levelId, cols, rows, timeLimitSec?, arrows: [{ id, headDir, cells: [[row,col],…] }] }`
  (canónico en `CONTEXT-MAP.md` raíz). Ids reales del seed: `level-01`…`level-15`.
- El AC "Dio con base URL por env" del issue **ya existe** (`lib/core/network/dio_client.dart`
  + `AppConfig.apiBaseUrl` + `AuthTokenInterceptor`). No se toca.
- Ya existe `LevelJsonEncoder` (`infrastructure/serialization/`), el inverso del decoder nuevo.
- Patrón de puertos remotos: `Either<Failure, T>` (dartz); `DioException` muere en el repo de
  infraestructura (referencia: `remote_auth_repository.dart`).
- Estado a reemplazar: `GameController.loadLevel` genera con
  `LevelBlueprint.forLevel(levelId.number)` + `GraphBoardGenerator`;
  `LevelSelectionScreen` hardcodea 12 niveles con ids `'1'..'12'`;
  `VictoryScreen` navega con `LevelId('${number + 1}')`.

## 3. Dominio (`lib/domain/board/`, Dart puro)

### 3.1 VO `Level` — `entities/level.dart`

`LevelId id`, `ArrowBoard board`, `int? timeLimitSec`. Equatable. Invariantes en
constructor: `timeLimitSec`, si existe, > 0; `board` con al menos una flecha (un nivel
oficial vacío no es jugable) — violación → excepción de dominio.

### 3.2 Sealed `LevelFailure` — `failures/level_failure.dart`

Espejo del patrón `AuthFailure`:

- `LevelNotFound(LevelId)` — 404 del back.
- `LevelUnavailable` — fallo de red Y sin copia en caché.
- `LevelCorrupted(String reason)` — el JSON (de red o de caché) no cumple el wire contract.

### 3.3 Puerto `ILevelRepository` — `repositories/i_level_repository.dart`

```dart
abstract interface class ILevelRepository {
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds();
  Future<Either<LevelFailure, Level>> getLevel(LevelId id);
}
```

El puerto queda mínimo: el prefetch NO es método del puerto; lo orquesta la capa de
aplicación reutilizando `getLevel` (el repo cachea como efecto natural).

## 4. Infraestructura (`lib/infrastructure/`)

### 4.1 `LevelRemoteDataSource` — `data_sources/remote/level_remote_data_source.dart`

`fetchLevelIds()` → `List<dynamic>` crudo de `GET /levels`; `fetchLevel(String id)` →
`Map<String, dynamic>` crudo de `GET /levels/:id`. Propaga `DioException` (mismo estilo que
los tres data sources existentes). Sin clase DTO.

### 4.2 `LevelJsonDecoder` — `serialization/level_json_decoder.dart`

`Level decode(Map<String, Object?> json)`. **Estricto**: clave ausente, tipo incorrecto,
`headDir` desconocido, `cells` vacío o celda malformada → lanza `FormatException` con
motivo. Simétrico a `LevelJsonEncoder`; propiedad golden: encodear el resultado de decodear
el JSON del wire contract reproduce el JSON original.

### 4.3 Caché Hive — box `levels_cache`

- Clave `catalog` → `List<String>` de ids en orden.
- Clave `level:<id>` → `String` con el **JSON crudo** del nivel.

Se persiste el JSON, no un modelo Hive tipado: el decoder es la única fuente de verdad del
parseo y no hay TypeAdapter nuevo que mantener. La box se abre en el arranque junto a las
existentes. Sin TTL: online siempre se refetchea (network-first).

### 4.4 `RemoteLevelRepository` — `repositories/remote_level_repository.dart`

Implementa `ILevelRepository`. Estrategia **network-first con fallback a caché**:

1. Intenta red; si responde: escribe caché (write-through) y devuelve `Right`.
2. `DioException` de red/timeout → lee caché; hay copia → `Right` silencioso; no hay →
   `Left(LevelUnavailable)`.
3. 404 → `Left(LevelNotFound(id))` (no consulta caché: el back es autoridad sobre existencia).
4. `FormatException` del decoder (venga de red o de caché) → `Left(LevelCorrupted(reason))`.

Aquí muere `DioException`. Logging vía `ILoggerService` inyectado (AOP; nunca `print`).

## 5. Application

### 5.1 `levelCatalogProvider` — `application/providers/`

`AsyncNotifier<List<LevelId>>`. Pide `listLevelIds()`; `Left` → `AsyncValue.error(failure)`.
Tras `Right`, dispara **prefetch en segundo plano** de toda la campaña: `getLevel(id)` por
cada id, **secuencial** (no ametrallar al back), `unawaited`; los fallos individuales se
loggean y se tragan — el prefetch es oportunista y nunca afecta a la UI. Con una visita
online, la campaña completa (~15 × 1-2 KB) queda jugable offline. Expone `refresh()` para
el retry de la UI.

### 5.2 `GameController.loadLevel(LevelId)` — de síncrono-generativo a asíncrono-remoto

1. `state = AsyncValue.loading()`.
2. `getLevel(id)` → `Left(failure)` → `state = AsyncValue.error(failure)`. Se reutiliza el
   `AsyncValue` que ya envuelve `GameState`; **no** se añade caso nuevo al sealed.
3. `Right(level)` → guarda `_currentLevelData = level`; tablero = `level.board`;
   `_remainingSeconds = level.timeLimitSec` (timer arranca igual que hoy si no es null);
   `_optimalMoves = level.board.arrows.length`.

**Restart** reusa `_currentLevelData` sin refetch (hoy regeneraba por seed).

Desaparecen del flujo de campaña: `LevelBlueprint.forLevel(...)`, el generador y
`levelId.number`. `ILevelGenerator` se retira del controller solo si nada más lo usa; el
generador y `LevelBlueprint` NO se borran (base del futuro front#36).

### 5.3 DI — `dependency_providers.dart`

`LevelRemoteDataSource(dio)` + box `levels_cache` + `LevelJsonDecoder` →
`RemoteLevelRepository` expuesto como `levelRepositoryProvider` (tipo `ILevelRepository`).

## 6. Presentación

- **`LevelSelectionScreen`**: `ref.watch(levelCatalogProvider)`; loading → spinner; error →
  mensaje + retry (`refresh()`); data → grid actual donde la celda `i` muestra `'${i + 1}'`
  (posición en el Catálogo) pero navega (juego y leaderboard) con el `LevelId` real. Esto
  alinea los scores del front con los ids del back.
- **`GameScreen`**: rama de error del `AsyncValue` discrimina `LevelFailure`:
  `LevelUnavailable` → mensaje sin-conexión + reintentar (`loadLevel` de nuevo);
  `LevelNotFound`/`LevelCorrupted` → mensaje terminal + volver a selección.
- **`VictoryScreen`**: lee el Catálogo de `levelCatalogProvider`;
  `next = ids[indexOf(actual) + 1]`. Último nivel → se oculta "Siguiente nivel" y aparece
  copy "¡Has completado todos los niveles!". Sin pantalla nueva.
- Nuevas keys de `AppLocalizations` (en/es) para: error de catálogo, sin conexión,
  reintentar, nivel no disponible/corrupto, campaña completada.

## 7. Tests (AAA, `should_..._when_...`)

En el plan, las tareas de test se redactan como **prompts para el subagente qa**
(preferencia del usuario), no como código inline. Cobertura requerida:

- `Level` VO: invariantes (timeLimit ≤ 0, board vacío).
- `LevelJsonDecoder`: golden ida-vuelta contra el JSON canónico del CONTEXT-MAP; ~5 casos
  corruptos (clave ausente, headDir desconocido, cells vacío, tipos incorrectos).
- `RemoteLevelRepository` (Dio mock + caché fake): happy path con write-through; fallback
  offline; 404; corrupto de red; corrupto de caché; sin-red-sin-caché.
- `levelCatalogProvider`: catálogo ok; error; el prefetch no rompe la carga si un nivel falla.
- `GameController` (repo mock): carga remota; error; restart sin refetch; timer con
  `timeLimitSec` remoto; `optimalMoves`.
- Widget tests: `LevelSelectionScreen` (loading/error-retry/data), `GameScreen` (ramas de
  fallo), `VictoryScreen` (siguiente del catálogo; último nivel).
- Test de contrato: respuesta Dio mockeada byte-idéntica al ejemplo del CONTEXT-MAP.

## 8. No-objetivos

- Migración del progreso local guardado bajo ids `'1'..'12'` (queda huérfano; no hay datos
  de producción).
- Sistema de desbloqueo de niveles (hoy no existe).
- TTL/invalidación de caché.
- Tocar `LevelBlueprint`, `GraphBoardGenerator` o sus tests (reservados a front#36).
- `LevelId.next()` y corrección de `LevelId.number` (superados por el Catálogo).

## 9. Housekeeping del fragmento

- Conventional Commits por fragmento + entrada `AI_HISTORY.MD` por fragmento.
- Actualizar `MazePruebaFront/README.md`: la campaña pasa a ser remota (arquitectura y uso).
- Comentar en el issue front#8 documentando la redefinición de alcance.
- DoD: `flutter analyze` limpio y suite completa verde.
