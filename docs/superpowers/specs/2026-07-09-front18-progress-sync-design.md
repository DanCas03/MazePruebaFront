# front#18 — Sync de progreso local con el servidor

**Fecha:** 2026-07-09
**Issue:** DanCas03/MazePruebaFront#18 — `feat(progress): sync local progress with server`
**Bloqueantes:** back#8 (POST/GET /progress) ✅ mergeado (PR #16) · front#14 ✅ cerrado

## Objetivo

Sincronizar el progreso local (Hive) con el servidor: al autenticarse, hacer pull
del progreso remoto, reconciliarlo con el local (**gana el mejor score**, un nivel
completado en cualquier lado queda completado), hacer push del merge y persistirlo
localmente. Manejar el error de red sin romper el flujo.

Ref: enunciado 5.2.2.

## Contrato del backend (back#8, ya mergeado)

```
POST /progress   (Bearer)
  body:  { levels: [{ levelId: string, completed: bool, bestScore?: int>=0, bestStars?: int 1..3 }] }
  201:   [{ levelId, completed, bestScore: number|null, bestStars: number|null }]   // merged

GET  /progress   (Bearer)
  200:   [{ levelId, completed, bestScore: number|null, bestStars: number|null }]
```

Regla de merge del server (`SyncProgressUseCase.merge`): `completed = a || b`;
`bestScore/bestStars = máximo`, tratando `null` como "peor" (un no-null gana a null).
El cliente reproduce esta misma regla para dejar el estado local correcto sin
depender del orden de respuesta del server.

## Enfoque elegido: A — Reconciliación en cliente + push/pull

Al autenticarse:

1. `pull()` → `GET /progress` → `List<LevelProgress>` remoto.
2. `getAll()` local (Hive) → `List<LevelProgress>` local.
3. `ProgressReconciler.reconcile(local, remote)` → merge (best score gana, completed OR).
4. `push(merged)` → `POST /progress` (el server re-mergea idempotente).
5. `upsertAll(merged)` → persistir el merge en Hive.

Enfoque descartado (B, cliente delgado: solo push + persistir respuesta del server):
la reconciliación viviría solo en el server, encaja peor con el criterio
"reconciliación (mejor score gana)" y no sirve offline.

## Diseño por capas (Clean Mobile Architecture)

### domain/ (Dart puro)

- **`LevelProgress`** (VO, `domain/board/value_objects/level_progress.dart`)
  Campos: `LevelId levelId`, `bool completed`, `int? bestScore`, `int? bestStars`.
  Validación en constructor: `bestScore >= 0` si no es null; `bestStars ∈ 1..3` si
  no es null. Igualdad por valor (Equatable).
  **No** usa el `Score`/`Stars` VO de front#12 (no mergeado; #18 no está bloqueado
  por él): `int?` mantiene #18 autocontenido y es espejo directo de los campos
  opcionales del server. Cuando front#12 aterrice, un refactor posterior puede
  cambiar a VOs sin tocar el contrato de sync.

- **`ProgressReconciler`** (servicio de dominio puro, `domain/board/services/progress_reconciler.dart`)
  `List<LevelProgress> reconcile(List<LevelProgress> local, List<LevelProgress> remote)`.
  Une por `levelId`; por nivel: `completed = local || remote`;
  `bestScore = maxNullable`; `bestStars = maxNullable` (no-null gana a null).

- **`IRemoteProgressRepository`** (puerto, `domain/board/repositories/i_remote_progress_repository.dart`)
  `Future<List<LevelProgress>> pull();`
  `Future<List<LevelProgress>> push(List<LevelProgress> progress);`

- **`ILevelProgressRepository`** (extensión del puerto local existente)
  Se añaden: `Future<List<LevelProgress>> getAll();` y
  `Future<void> upsertAll(List<LevelProgress> progress);`
  (Los métodos actuales `getProgress/saveProgress/markCompleted/isCompleted` se
  mantienen — no se rompe a los consumidores existentes: OCP/LSP.)

### infrastructure/

- **`LevelProgressHiveModel`** — se añaden `@HiveField(3) int? bestScore` y
  `@HiveField(4) int? bestStars` (aditivo y retrocompatible: registros viejos leen
  `null`). Regenerar `.g.dart` con build_runner.

- **`HiveLocalDataSource`** — métodos `getAllProgress()` y
  `upsertProgress(levelId, completed, bestScore, bestStars)` (o `putAll`).

- **`HiveProgressRepository`** — implementa `getAll()`/`upsertAll()` mapeando
  `LevelProgressHiveModel` ↔ `LevelProgress`.

- **`RemoteProgressDataSource`** (Dio, `infrastructure/data_sources/remote/remote_progress_data_source.dart`)
  `GET /progress` y `POST /progress`. Usa el `Dio` compuesto en `main` (con el
  `AuthTokenInterceptor`).

- **`RemoteProgressRepository`** (`infrastructure/repositories/remote_progress_repository.dart`)
  Implementa `IRemoteProgressRepository` mapeando `LevelProgress` ↔ JSON del backend.

### application/

- **`SyncProgressUseCase`** (`application/use_cases/sync_progress_use_case.dart`)
  Orquesta pull → reconcile → push → persistir. Inyecta `IRemoteProgressRepository`,
  `ILevelProgressRepository`, `ProgressReconciler` e `ILoggerService` (AOP).
  Ante error de red: loguea y retorna sin propagar (la sesión/flujo continúa).

- **Disparo**: listener de `authControllerProvider` (en la composición / `AuthGate`)
  que llama a `SyncProgressUseCase.execute()` al transicionar a `Authenticated`.
  Providers nuevos en `dependency_providers.dart` (composición DIP).

## Manejo de errores

- Fallo de red en pull o push → `ILoggerService.error(...)` + return temprano; el
  progreso local no se corrompe y el flujo de UI no se rompe (criterio explícito).
- Datos malformados del server → se descartan filas inválidas al mapear (el VO
  valida); se loguea.

## Tests (AAA, `should_..._when_...`)

1. **`ProgressReconciler`** (unit, dominio puro):
   - best score gana cuando ambos lados tienen score
   - no-null gana a null
   - `completed = OR`
   - nivel presente solo en un lado se conserva
2. **`RemoteProgressRepository`** con `RemoteProgressDataSource` mockeado:
   - mapea la respuesta del backend a `List<LevelProgress>`
   - serializa el push al shape correcto
3. **`SyncProgressUseCase`** con puertos mockeados:
   - pull+reconcile+push+persist en orden
   - error de red → no lanza, loguea
4. **`LevelProgress`** VO: validación de `bestStars`/`bestScore`.

## Alcance / notas

- **Interceptor `remember:false`**: los `/progress` son autenticados y heredan el
  gap documentado en `auth_token_interceptor.dart` (token en memoria no se adjunta).
  Con `remember:true` (default) funciona; el path `remember:false` queda pendiente
  de front#16. Se documenta inline; **no** se arregla aquí (entregable de front#16).
- **Poblar el score local**: hoy el juego no produce score (front#12/#16). front#18
  aporta la tubería; `bestScore/bestStars` locales se llenarán cuando front#16 los
  guarde tras la victoria. La reconciliación se testea con snapshots construidos.

## DoD

Tests AAA verdes, `flutter analyze` limpio, Conventional Commit(s) por fragmento +
entrada `AI_HISTORY.MD`, README si toca API pública. Rebase sobre `main` antes de PR.
