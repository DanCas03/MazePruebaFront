# Arrow Maze — Flutter Client

[![CI](https://github.com/DanCas03/MazePruebaFront/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/DanCas03/MazePruebaFront/actions/workflows/ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%3E%3D3.3-0175C2?logo=dart&logoColor=white)
![Riverpod](https://img.shields.io/badge/State-Riverpod-3F51B5)
![Hive CE](https://img.shields.io/badge/Storage-Hive%20CE-FFCA28)
![License](https://img.shields.io/badge/license-private-lightgrey)

> CI runs `flutter analyze` + `flutter test` on every PR and on `main` (see [.github/workflows/ci.yml](.github/workflows/ci.yml)); `main` requires a green build plus one review to merge.

A casual mobile puzzle game built with Flutter. The board is filled with multi-cell arrows of varying sizes and directions. Tap an arrow to slide it in its facing direction; if the path to the board edge is clear of other arrows, it exits. Clear every arrow to win the level.

## Description

Arrow Maze is the client half of a two-repository project (the [backend API](https://github.com/DanCas03/MazePruebaBack) serves levels and authentication). The interesting part is the structure: this is **Clean Mobile Architecture** (Petros Efthymiou) applied to Flutter. The `domain/` layer is pure Dart with no Flutter, Hive, or Riverpod imports; game rules live there. The UI consumes Riverpod providers from `application/` and never reaches into `infrastructure/` or `domain/` directly. Undo is a real Command pattern, the board is an Aggregate Root, and the level generator builds solvable-by-construction puzzles of bent, serpentine arrows on a tall, densely packed board.

**Tech stack:** Flutter (Dart >= 3.3), Riverpod for state and DI, Hive CE for local persistence, `dartz` for `Either`/`Option`, `equatable` for value equality, `logger` behind an AOP adapter, `audioplayers` behind an audio facade, `build_runner` for code generation, and `flutter_test` + `mockito` for tests.

## Screenshots

Screenshots and a gameplay GIF are pending. To see the UI (dark-neon palette, glassmorphism panels, 3-D arrows, light/dark following the system theme), run the app with `flutter run`.

## Architecture

The dependency rule points inward: `infrastructure` and `presentation` depend on `application`, `application` depends on `domain`, and `domain` depends on nothing external.

```
lib/
├── domain/          Pure Dart — entities, value objects, exceptions, port interfaces
│   ├── arrows/      Arrow, ArrowBoard (aggregate root), ArrowId, ArrowLength, ILevelGenerator, Difficulty, GeneratorConfig, GeneratedBoard
│   ├── board/       LevelId, Level, LevelFailure, SolutionFailure, ILevelRepository, ISolutionRepository, HintPolicy, ILevelProgressRepository, IRemoteProgressRepository, ProgressReconciler
│   ├── game_core/   Position, Direction, MoveCount, Score, Stars
│   ├── leaderboard/ ScoreEntry, LeaderboardEntry, ILeaderboardRepository (port — submit + read)
│   ├── auth/        Email, AuthToken, IAuthTokenStorage (port)
│   └── core/        Domain exception hierarchy
├── application/     Use cases, Commands (undo), GameState (sealed), Riverpod Notifiers
│   ├── commands/    ICommand, CommandInvoker, RemoveArrowCommand
│   ├── state/       GameState / AuthState (sealed), GameController / AuthController (AsyncNotifier)
│   ├── use_cases/   RemoveArrowUseCase, RestoreSessionUseCase (auto-login), LoginUseCase, RegisterUseCase, SyncProgressUseCase, SubmitScoreUseCase, GetLeaderboardUseCase, GenerateBoardUseCase
│   └── providers/   leaderboard_providers.dart (submitScoreUseCaseProvider, scoreSubmissionObserverProvider — Observer, getLeaderboardUseCaseProvider, leaderboardProvider — FutureProvider.family), level_catalog_provider.dart (levelCatalogProvider — remote catalog + campaign prefetch)
├── infrastructure/  Hive persistence, secure token storage, RemoteAuthRepository, RemoteProgressRepository, RemoteLeaderboardRepository, RemoteLevelRepository (campaign, `levels_cache` box), GraphBoardGenerator (implements the domain ports)
├── presentation/    Screens, Widgets, Painters + providers/ (the only place infra is built)
│   ├── auth/        Login/register screens (LoginScreen, RegisterScreen) and shared auth widgets
│   └── leaderboard/ LeaderboardScreen (per-level ranking view)
├── core/            Cross-cutting: aspects/ (logger), auth/ (AuthGate route guard), config/ (AppConfig), network/ (DioClient, AuthTokenInterceptor), theme/, router/
└── l10n/            i18n (front#4): app_en.arb / app_es.arb + generated AppLocalizations delegate (see Tooling → Localization)
```

The rule that keeps the boundary honest: `domain/` imports nothing from Flutter, Hive, or Riverpod, and every Riverpod provider that constructs a concrete `infrastructure/` class lives in `presentation/providers/`.

## Tooling

### Producción de candidatos de nivel — Rampa + CLI (front#65)

    dart run tool/level_production/produce.dart --tier <1..5> --seeds <A..B> [--out <dir>] [--finale] [--budget <seg>]

Corre la **Rampa de producción** ([`tool/level_production/ramp.dart`](tool/level_production/ramp.dart)) —
la curva de dificultad de la campaña, sucesora del retirado `LevelBlueprint`—
sobre un rango de semillas y congela un JSON arrow-path por candidato más un
manifiesto del lote. La Rampa mapea cada tier a dimensiones, densidad
(`fillRatio`), largo máximo de camino y (de T3 en adelante) un `timeLimitSec`
derivado (`arrowCount × 4`, redondeado hacia arriba a múltiplos de 30; T1–T2 sin
límite). La campaña conserva su estructura 15 = 5 tiers × 3 y remata en un 50×50
(`--tier 5 --finale`, nivel 15, `fillRatio` 0.65).

Ejemplos:

    dart run tool/level_production/produce.dart --tier 3 --seeds 300..309
    dart run tool/level_production/produce.dart --tier 5 --finale --seeds 900..909

Cada candidato lleva un id trazable `cand-tN-sNNN` (tier + seed; **placeholder**
hasta que la curación asigne el identificador final) y un `order` placeholder =
tier. Salida en `out/candidates/` por defecto (el directorio se crea recursivo
si no existe):

- `cand-tN-sNNN.json` — JSON `{levelId, order, cols, rows, timeLimitSec?, arrows[]}`.
- `manifest-tN.md` — tabla del lote (dims, flechas colocadas/pedidas, densidad
  lograda, duración).
- `errors-tN.md` — manifiesto de errores (solo si alguna semilla falló).

**Determinista** (misma semilla + parámetros ⇒ JSON idéntico dentro de la misma
versión del SDK; el artefacto congelado real es el JSON en git). **Validación
integrada** antes de escribir: cada candidato pasa *sin solape* + *vaciado en
orden inverso de colocación* (solubilidad por construcción). **Resiliente**:
cada semilla se genera en un isolate con presupuesto de tiempo (`--budget`, 5 s
por defecto); una semilla que exceda el tiempo o falle la validación se registra
en el manifiesto de errores y el lote continúa. Los candidatos elegidos por la
curación alimentan el seed del back (back#10).

### Campaña remota (front#8)

Los niveles de la campaña ya no se generan localmente: los sirve el back oficial. `GET /levels` devuelve el Catálogo (los `LevelId` en orden de juego) y `GET /levels/:id` el nivel completo (`ArrowBoard` + arrows). La app depende del puerto [`ILevelRepository`](lib/domain/board/repositories/i_level_repository.dart); la implementación [`RemoteLevelRepository`](lib/infrastructure/repositories/remote_level_repository.dart) es network-first con fallback a caché: con red, refetchea y hace write-through a una box Hive `levels_cache`; sin red (o ante un error de servidor no-404), sirve la copia cacheada. Un 404 del back para un nivel concreto es autoritativo (`LevelNotFound`) y no consulta la caché.

[`levelCatalogProvider`](lib/application/providers/level_catalog_provider.dart) (`LevelCatalogNotifier`, `AsyncNotifier`) carga el Catálogo al arrancar y dispara en segundo plano un prefetch secuencial de toda la campaña vía `getLevel` (que cachea como efecto colateral); los fallos individuales del prefetch se loggean y se tragan. Tras una visita online, la campaña queda jugable **offline**. "Siguiente nivel" en la pantalla de victoria sigue el orden del Catálogo, no un cálculo local. La app necesita alcanzar el back en `AppConfig.apiBaseUrl` (por defecto `http://10.0.2.2:3000` para el emulador de Android, configurable con `--dart-define=API_BASE_URL=...`).

El generador local ([`GraphBoardGenerator`](lib/infrastructure/generators/graph_board_generator.dart)) se conserva en el código pero ya no alimenta la campaña; ahora alimenta la feature "Generar nivel" (front#36) de tableros efímeros — ver *Tooling → Player-generated boards*.

> **Nota (front#9 — reconciliación).** El *Strategy intercambiable remoto/procedural* que imaginaban el backlog (E1.5) y el issue front#9 —con la generación procedimental como "modo práctica/fallback"— **no se construyó, a propósito**. Tras el cutover (ADR 0001, en `docs/adr/` del workspace), la fuente de niveles de la campaña es **DIP puro**: el puerto [`ILevelRepository`](lib/domain/board/repositories/i_level_repository.dart) con un **único Adapter de producción** (`RemoteLevelRepository`), no una familia de estrategias dentro de `loadLevel`. El **offline** lo resuelve la **caché** (network-first, arriba), no un tablero generado; sin red ni caché el resultado es `LevelUnavailable`, no un board de reemplazo. La generación procedimental es una **feature aparte** —`GeneratedBoard`, front#36/#37—: sus tableros son efímeros, sin `LevelId`, sin score ni progreso, y **nunca** sustituyen a un `Level` oficial. (`GraphBoardGenerator` sí es un Strategy, pero de `ILevelGenerator`, no de la campaña.) Por eso front#9 se cierra como documentación: los criterios 1 y 3 los entregó front#8, y el criterio 2 quedó superado por este diseño.

### Pista auto-resolutora (#32)

En los niveles difíciles (número ≥ 7, umbral único en [`HintPolicy`](lib/domain/board/services/hint_policy.dart)) el AppBar muestra una **bombilla** que reproduce la solución canónica del servidor como una **demo no puntuable**. Al pulsarla, `GameController.playHint()` pide la *Solución* al back (`GET /levels/:id/solution`, back#19) a través del puerto [`ISolutionRepository`](lib/domain/board/repositories/i_solution_repository.dart); la implementación [`RemoteSolutionRepository`](lib/infrastructure/repositories/remote_solution_repository.dart) mapea la respuesta (`{levelId, solution: [ids]}`) a `List<ArrowId>` en orden de vaciado. El cliente **reproduce ese orden verbatim** —nunca deriva la secuencia—: reinicia el tablero y anima la salida de cada flecha reutilizando el mismo mecanismo de *exit animation* (`exitingArrow` + `exitNonce`) que un tap real. Durante la demo el input y el undo quedan **bloqueados** y no se cuentan movimientos ni choques (la pila de undo del `CommandInvoker` no se toca); al terminar, el nivel **se reinicia y queda jugable**.

Dos refuerzos de robustez sobre lo pedido:

- **Sub-estado de carga.** Mientras la petición HTTP viaja, `GamePlaying.hintLoading` transforma la bombilla en un *spinner* inerte, mitigando dobles clics accidentales; un token de generación (`_hintRun`) invalida cualquier demo en vuelo si el jugador carga otro nivel, reinicia o la pantalla se destruye.
- **Timeout estricto.** [`SolutionRemoteDataSource`](lib/infrastructure/data_sources/remote/solution_remote_data_source.dart) impone un `receiveTimeout` por request (5 s, más corto que el global del Dio): si el back tarda o falla, la llamada **rompe limpio** hacia `SolutionUnavailable`, se dispara un *snackbar* de error y **la partida en curso queda intacta**. No hay caché: la pista es on-demand y offline resuelve "no disponible" en vez de servir una copia vieja. Un 404 mapea a `SolutionNotFound` y un 422 (nivel insoluble) a `SolutionUnsolvable`.

Coherente con **ADR 0002**: solo los niveles curados del back tienen *Solution*; los tableros generados (front#36) no la tienen y quedan fuera de esta feature.

### Auth flow

Login and registration hit the backend at `POST /auth/login` and `POST /auth/register` (base URL configurable via `--dart-define=API_BASE_URL=...`, defaulting to `http://10.0.2.2:3000` for the Android emulator). Registration requires `email`, `username` (3-20 chars, letters/digits/underscore, validated client-side by the `Username` VO — the back rejects a missing/invalid one with 400) and `password` (≥8 chars); a taken email or username gets a 409, mapped to `EmailAlreadyRegistered`. A successful call persists the returned JWT through `IAuthTokenStorage` (front#14); `AuthGate`, sitting at the `MaterialApp`'s `home`, watches `authControllerProvider` and swaps from `LoginScreen` to the game flow (`HomeScreen`) as soon as the session becomes `Authenticated` — no manual navigation call is needed after login.

### Progress sync (front#18)

On the `Unauthenticated → Authenticated` transition (login or auto-login), `AuthGate` fires `SyncProgressUseCase.execute()` once via `ref.listen`. The use case pulls the server's progress (`GET /progress`) through the `IRemoteProgressRepository` port (`RemoteProgressRepository`, Dio-backed, in `infrastructure/`), reconciles it with the local Hive progress using the domain service `ProgressReconciler` — best score wins per level, and a level completed on either side stays completed — pushes the merged result back (`POST /progress`), and persists it locally through `ILevelProgressRepository`. The sync is fire-and-forget: network failures are logged (AOP) and swallowed, so a sync failure never blocks the auth guard or the game flow.

**Known limitation:** with "remember me" unchecked (`remember: false`), `AuthTokenInterceptor` does not yet sign requests from the in-memory session, so the sync's authenticated calls only succeed when "remember me" is checked, until front#16 fixes the interceptor.

### Localization (i18n · front#4)

The app ships Spanish (`es`, primary) and English (`en`), selected automatically from the device locale. Strings live in ARB files under [`lib/l10n/`](lib/l10n/) (`app_en.arb` is the key template, `app_es.arb` the Spanish translation); [`l10n.yaml`](l10n.yaml) drives `flutter gen-l10n`, which produces the `AppLocalizations` delegate. Because `flutter: generate: true` is set in `pubspec.yaml`, the delegate is regenerated on every `flutter pub get` / build, so the generated `lib/l10n/app_localizations*.dart` files are **not** committed (they are git-ignored).

Screens read strings through `AppLocalizations.of(context)`; there is no static string table. To add or change a string: edit both ARB files (same key), then run `flutter gen-l10n` (or `flutter pub get`). Messages with runtime values use ICU placeholders, e.g. `gameMoves(count)` → `"Moves: 3"` / `"Movimientos: 3"`.

### Settings & live language switching (front#19)

The **Settings screen** (gear icon on Home, route `/settings`) exposes **independent** Music (BGM) and SFX toggles over the [`IAudioService`](lib/application/audio/i_audio_service.dart) facade, plus an **ES / EN / System** language selector — all persisted. Because the facade's mutes are plain getters (not observable), a Riverpod `Notifier` (`audioSettingsControllerProvider`) publishes a reactive `AudioSettingsState` and delegates each toggle to a thin use case (`ToggleMusicUseCase` / `ToggleSfxUseCase`). Language is driven by `localeControllerProvider` (a `Notifier<Locale?>`, `null` = follow the OS; the **System** segment sets it back to `null`): `ArrowMazeApp` watches it and sets `MaterialApp.locale`, so switching language **rebuilds the tree and re-evaluates every `AppLocalizations.of(context)` live**, with no restart. The controllers receive their dependency (`IAudioService` / `ILocaleStore`) **by constructor** — `application/` never imports `presentation/`, and `main` composes the real instances via `overrideWith` (same pattern as `gameControllerProvider`). The choice persists behind the `ILocaleStore` port (`HiveLocaleStore` over the `app_settings` box; `InMemoryLocaleStore`, in `application/settings/`, is the default null-object). `SetLanguageUseCase` performs the persistence.

### Score submission (front#16)

On winning a level, `GameController` computes the run's `Score`/`Stars` and emits an enriched `GameWon` state (`{moves, score, stars, timeSeconds, levelId}`). An Observer (`scoreSubmissionObserverProvider`), activated by `GameScreen` via `ref.watch`, listens to `gameControllerProvider` and, on `GameWon`, builds a `ScoreEntry` and fires `SubmitScoreUseCase` fire-and-forget. The use case sends `POST /scores` (`{levelId, score, stars, moves, timeSeconds}`) through `RemoteLeaderboardRepository` (implements the domain port `ILeaderboardRepository`) and `LeaderboardRemoteDataSource` (Dio). The request is signed with the live session's Bearer token via `ISessionTokenStore`, which also covers `remember: false` sessions (front#16's interceptor fix). A network failure is logged (AOP) and swallowed by the use case, so the victory screen is never blocked by the submission.

### Leaderboard view (front#17)

The level-selection screen exposes a ranking icon per level; tapping it opens `LeaderboardScreen`, which reads the public `GET /leaderboard/:levelId` (back#9). The screen watches `leaderboardProvider` (`FutureProvider.autoDispose.family` keyed by `levelId`), which runs `GetLeaderboardUseCase` through the same `ILeaderboardRepository` port — now cohesive around submit **and** read. `RemoteLeaderboardRepository.getLeaderboard` maps the back's rows (`{id, userId, username, levelId, score, stars, moves, timeSeconds, createdAt}`) to `LeaderboardEntry`, preserving the server's score-desc order (rank is positional). The UI renders the three `AsyncValue` states — a loading spinner, an error state with a retry button, and the ranked list (empty state when a level has no scores yet). Unlike the fire-and-forget submit, the read use case rethrows on failure so the UI can surface the error. The tile shows the entry's `username` (front#50) rather than the raw `userId` UUID.

### Level selection (front#20 + front#8)

`LevelSelectionScreen` renders the **remote catalog** grouped by **Tier** — difficulty rungs of three levels each, which also drive the difficulty labels shown to the player (Easy / Medium / Hard). Each unlocked tile shows the level's **position in the catalog** (the backend's `LevelId` is opaque and only travels in navigation/scoring) and the level's earned stars (0–3), and navigates to the game on tap (plus the per-level ranking icon from front#17); each locked tile shows a padlock and does nothing. The catalog list comes from `levelCatalogProvider` (front#8): `GET /levels` through the `ILevelRepository` port, downloaded once per session, with an opportunistic background prefetch of the whole campaign so one online visit makes it playable offline. The Tier of each level derives from its **position** in the catalog (`Tier.forLevelNumber(position)`) — never from arithmetic on the id.

Gating lives in the pure domain service `TierGating`: the first Tier is always open, and a Tier unlocks once **every** level of the lower-ranked Tiers is completed. `LevelSelectionController` (`AsyncNotifier`) composes the catalog (via `ref.watch` on `levelCatalogProvider`), the local progress (`ILevelProgressRepository.getAll`, whose `bestStars` feed the star row and degrade to 0 when no score exists yet) and `TierGating` into per-Tier view models. The screen invalidates the provider on entry (`ref.invalidate` in a post-frame callback) and on reveal-by-pop (`RouteAware.didPopNext`), so returning from a won level reflects the freshly earned stars and any newly unlocked Tier — re-reading only the local progress, since the already-resolved catalog is reused. If the catalog fails (offline and no cache), the screen shows an error state with a retry button that refreshes the catalog.

### Player-generated boards (front#36) — application half

"Generar nivel" lets the player request an **ephemeral, locally generated, solvable board**: board dimensions, a difficulty preset, an optional timer and an optional seed. This issue ships the **domain + application half** of the feature; the UI that collects the input and plays the board is a separate issue. The resulting artifact is a **GeneratedBoard** (*Tablero generado*, see the glossary in [`CONTEXT.md`](CONTEXT.md)): unlike a `Level`, it has no `LevelId`, is never scored, never persisted, and never touches `Progress` or the leaderboard — it is played and discarded, reproducible via `(seed, config)` within the same app version.

**[`GeneratorConfig`](lib/domain/arrows/value_objects/generator_config.dart)** is a defensive value object: it can only be built through the `GeneratorConfig.create` factory, which validates that `cols` and `rows` fall in the playable range **4–50 inclusive** (`minDimension`/`maxDimension`, adjustable in one place; the ceiling rose from 10 to 50 in front#66 once the zoom/pan viewport made large boards legible on mobile) and throws the semantic domain failure [`InvalidGeneratorConfigException`](lib/domain/core/exceptions/invalid_generator_config_exception.dart) otherwise. The player chooses *intent* (size, difficulty, timer); the internal generator parameters are **derived** from the [`Difficulty`](lib/domain/arrows/value_objects/difficulty.dart) preset constants:

| Preset | Arrow density (`fillRatio`) | `maxPathLen` | Timer budget (`secondsPerCell`) |
|---|---|---|---|
| `easy` | 0.40 | 3 | 3.0 s |
| `medium` | 0.55 | 6 | 2.0 s |
| `hard` | 0.70 | 9 | 1.5 s |

- `arrowCount` = `round(cols · rows · fillRatio / avgPathLen)` with `avgPathLen = (2 + maxPathLen) / 2`, clamped to `[4, cells ~/ 2]` — the same density model the campaign used (`LevelBlueprint`).
- `timeLimitSec` (only when `timed: true`, otherwise `null`) = `round(cols · rows · secondsPerCell)`, clamped to `[30, 300]` s.

**[`GenerateBoardUseCase`](lib/application/use_cases/generate_board_use_case.dart)** consumes the existing [`ILevelGenerator`](lib/domain/arrows/services/i_level_generator.dart) port (implemented by `GraphBoardGenerator`, whose DAG construction makes every board **solvable by construction**). If the player did not fix a seed, the use case completes it through an injectable `SeedSource` (defaulting to `Random`) — randomness is the only non-deterministic effect and it is isolated behind that seam, so tests inject a fixed source and `execute` stays pure given its input. The result is a [`GeneratedBoard`](lib/domain/arrows/value_objects/generated_board.dart) bundling the `ArrowBoard`, the **effective config** and the **seed used** (always surfaced: same seed + same config ⇒ identical board). The generator's graceful degradation (fewer arrows than requested on dense configs) is accepted as-is. The use case performs **no persistence** — no Hive boxes, no `Progress`, no score submission.

Presentation reaches the use case through `generateBoardUseCaseProvider` in the composition root ([`dependency_providers.dart`](lib/presentation/providers/dependency_providers.dart)), which composes the `ILevelGenerator` port with the AOP logger (the seed is logged for reproducibility).

Per **ADR 0002**, the canonical auto-solve *Solution* is produced by the backend for curated levels only; generated boards never reach the backend, carry no Solution, and the hint/auto-solve feature is explicitly out of scope for this flow — solvability is guaranteed by construction instead.

> **Performance (front#64).** `ArrowBoard` caches its occupancy set lazily per instance (it is immutable, so each `removeArrow` yields a fresh instance whose cache is recomputed once), and `GraphBoardGenerator` keeps an incremental occupancy state that is updated as each arrow is accepted instead of being rebuilt per attempt. This makes dense 50×50 generation (ADR 0003: campaign finale and XL presets) finish in well under 2 s; behavior is unchanged (same public interfaces, seed→output still deterministic).

### Player-generated boards (front#37) — UI half

The player half of "Generar nivel" is a self-contained flow — **Home → configurator → generated game → post-game** — that reuses the campaign's play mechanics but is walled off from all persistence.

- **Zero-persistence firewall (structural).** [`GeneratedGameController`](lib/application/state/generated_game_controller.dart) (`AsyncNotifier<GameState>`) is composed with only `GenerateBoardUseCase` + `RemoveArrowUseCase` + `CommandInvoker` + `ITicker` — it has **no** `ILevelRepository`, `SubmitScoreUseCase` or `ILevelProgressRepository`, so it *cannot* write Hive, touch `Progress` or submit to the leaderboard. Unlike the campaign screen, the generated screen never watches `scoreSubmissionObserverProvider`, so clearing a board never fires a score POST. Victory is a dedicated `GeneratedCleared` state carrying only `MoveCount` — a mirror of `GameWon` with no `Score`/`Stars`/`LevelId`.
- **Configurator.** [`ConfiguratorScreen`](lib/presentation/generated/configurator_screen.dart) collects the player's *intent*: `cols`/`rows` steppers clamped to 4–10, a `Difficulty` segmented button, a timed toggle and an optional seed. [`ConfiguratorController`](lib/application/state/configurator_controller.dart) (an `autoDispose` `NotifierProvider`) drives an immutable [`ConfiguratorState`](lib/application/state/configurator_state.dart) whose `isValid` **disables the "Play" button reactively** when the optional seed is not a whole number.
- **Game HUD.** [`GeneratedGameScreen`](lib/presentation/generated/generated_game_screen.dart) reuses the shared `BoardView` (extracted from `BoardWidget` so both flows render identically), the move counter, the countdown (only when the player enabled the timer), undo and audio. It shows the **seed subtly** at the foot with a **copy-to-clipboard** button (`SeedChip`) and hides hints, scores and stars entirely.
- **Post-game.** [`GeneratedResultScreen`](lib/presentation/generated/generated_result_screen.dart) carries no score/stars/next-level. It surfaces the final seed (copyable) and the four required actions: **Otro tablero** (`anotherBoard` — same config, new seed), **Repetir** (`repeat` — same seed and config ⇒ identical board), **Cambiar parámetros** (back to the configurator) and **Salir** (Home).

Routes `/generate`, `/generate/play` and `/generate/result` live in `AppRouter`; `main.dart` overrides `generatedGameControllerProvider` with the real `GraphBoardGenerator`, the pure mechanics and `SystemTicker`.

## Design Patterns

| Pattern | Where | Problem it solves |
|---|---|---|
| **Command** | [`command.dart`](lib/application/commands/command.dart), [`command_invoker.dart`](lib/application/commands/command_invoker.dart), [`remove_arrow_command.dart`](lib/application/commands/remove_arrow_command.dart) | Models a move as a reversible operation. The invoker keeps history and delegates `undo` back to each command, so reversal logic lives with the operation. |
| **Aggregate Root** | [`arrow_board.dart`](lib/domain/arrows/entities/arrow_board.dart) | `ArrowBoard` is the single entry point to the arrows; lookups are private, so no consumer iterates the arrow list outside the root. |
| **Adapter** | [`logger_service_adapter.dart`](lib/core/aspects/logger_service_adapter.dart), [`secure_auth_token_repository.dart`](lib/infrastructure/repositories/secure_auth_token_repository.dart), [`remote_auth_repository.dart`](lib/infrastructure/repositories/remote_auth_repository.dart), [`remote_progress_repository.dart`](lib/infrastructure/repositories/remote_progress_repository.dart), [`remote_leaderboard_repository.dart`](lib/infrastructure/repositories/remote_leaderboard_repository.dart), [`remote_level_repository.dart`](lib/infrastructure/repositories/remote_level_repository.dart), [`auth_token_interceptor.dart`](lib/core/network/auth_token_interceptor.dart) | Wraps an external package/API behind a domain port, isolating the rest of the app from its concrete shape: `logger` behind `ILoggerService`, `flutter_secure_storage` behind `IAuthTokenStorage`, Dio behind `IAuthRepository` (`RemoteAuthRepository` translates HTTP/`DioException` into `AuthToken`/`AuthFailure`), behind `IRemoteProgressRepository` (`RemoteProgressRepository` maps `LevelProgress` to/from the `/progress` JSON shape), behind `ILeaderboardRepository` (`RemoteLeaderboardRepository` maps `ScoreEntry` to the `/scores` JSON shape) and behind `ILevelRepository` (`RemoteLevelRepository` maps the back's `/levels` JSON to `Level`, network-first with a `levels_cache` fallback), and the token header injection behind a Dio `Interceptor`. |
| **AOP + Adapter** | [`auth_token_interceptor.dart`](lib/core/network/auth_token_interceptor.dart) | `AuthTokenInterceptor` (a Dio `Interceptor`) injects `Authorization: Bearer <token>` on every outgoing request by reading `IAuthTokenStorage`, so authenticated calls never repeat that boilerplate in application code. |
| **Observer** | [`leaderboard_providers.dart`](lib/application/providers/leaderboard_providers.dart) | `scoreSubmissionObserverProvider` listens to `gameControllerProvider` and reacts to `GameWon` by submitting the score, decoupling `GameController` from the leaderboard concern entirely. |
| **Strategy** | [`graph_board_generator.dart`](lib/infrastructure/generators/graph_board_generator.dart) | `GraphBoardGenerator` implements `ILevelGenerator` as a swappable generation algorithm (a DAG that guarantees solvability). No longer feeds the campaign (front#8 moved that to the back's official levels); it now powers the ephemeral player-generated boards consumed by `GenerateBoardUseCase` (front#36). |
| **Composition Root (DI)** | [`dependency_providers.dart`](lib/presentation/providers/dependency_providers.dart) | The one place concrete infrastructure is instantiated and injected as abstractions. |
| **Custom Painter** | [`arrow_painter.dart`](lib/presentation/game/painters/arrow_painter.dart) | Procedural rendering of arrows with a 3-D glow, avoiding image assets. |
| **Facade + Singleton** | [`audio_service.dart`](lib/infrastructure/audio/audio_service.dart) | `AudioService` is the single entry point to the audio subsystem behind the [`IAudioService`](lib/application/audio/i_audio_service.dart) port: it maps game events (`GameSound`) to asset paths and applies the **independent** mute rules (master / music / SFX), hiding players and formats. One instance for the app's lifetime (lazy Singleton + a single Riverpod provider). The concrete `audioplayers` package sits behind the [`IAudioBackend`](lib/infrastructure/audio/i_audio_backend.dart) adapter, and mute state persists via [`IAudioSettingsStore`](lib/infrastructure/audio/i_audio_settings_store.dart) (Hive). |
| **Decorator (AOP)** | [`logging_audio_decorator.dart`](lib/infrastructure/audio/logging_audio_decorator.dart) | Wraps `IAudioService` to log every audio operation through `ILoggerService` without touching the facade — the second cross-cutting aspect, applied by composition. |
| **Null Object** | [`silent_audio_service.dart`](lib/application/audio/silent_audio_service.dart) | `SilentAudioService` is the default `audioServiceProvider` value: a no-op `IAudioService` so widget tests and un-composed layers run without the real (Hive- and player-backed) audio. |

## SOLID Principles

**Single Responsibility.** [`ArrowBoard`](lib/domain/arrows/entities/arrow_board.dart) holds only board state and the rules over it (`isCleared`, `canExit`, `removeArrow`); it does not render, persist, or track moves.

**Open/Closed.** Board generation is open for extension through the [`ILevelGenerator`](lib/domain/arrows/services/i_level_generator.dart) port. Swapping `GraphBoardGenerator` for another algorithm means a new implementation, not edits to the use cases that consume it.

**Liskov Substitution.** Any [`ICommand`](lib/application/commands/command.dart) is interchangeable inside the `CommandInvoker`; the invoker calls `execute`/`undo` without knowing the concrete command:

```dart
ArrowBoard executeCommand(ICommand command, ArrowBoard board) {
  final newBoard = command.execute(board);
  _history.add(command);
  return newBoard;
}
```

**Interface Segregation.** Ports stay minimal: `ICommand` declares two methods (`execute`, `undo`), `ILoggerService` three, `ILevelProgressRepository` only what persistence needs.

**Dependency Inversion.** `application/` and `presentation/` depend on abstractions; concretes are injected at the composition root:

```dart
// presentation/providers/dependency_providers.dart
final loggerServiceProvider = Provider<ILoggerService>((_) => LoggerServiceAdapter());
final levelGeneratorProvider = Provider<ILevelGenerator>((_) => GraphBoardGenerator());
```

## AOP — Cross-Cutting Concerns

Logging is a cross-cutting concern, kept out of the business logic and injected as a port. The strategy rests on Dependency Inversion: domain and application code depend on the [`ILoggerService`](lib/core/aspects/i_logger_service.dart) abstraction, never on the concrete `logger` package. The single concrete implementation, [`LoggerServiceAdapter`](lib/core/aspects/logger_service_adapter.dart), lives in `core/aspects/` and is provided once for the whole app via `loggerServiceProvider`, so there is exactly one logging point to configure or replace.

```dart
// core/aspects/i_logger_service.dart — the port the app depends on
abstract interface class ILoggerService {
  void log(String message, String context);
  void error(String message, String context, [Object? error]);
  void warn(String message, String context);
}
```

A **second aspect** follows the same discipline for audio: [`LoggingAudioDecorator`](lib/infrastructure/audio/logging_audio_decorator.dart) wraps the `IAudioService` facade and routes every play / mute / lifecycle call through the same `ILoggerService`. Audio telemetry is added by composition at the composition root, so the facade and the presentation observer that fires sounds stay free of logging code. The observer itself keeps the dependency rule intact: the game screen reacts to existing `GameState` signals (`exitNonce`, `blockedNonce`, `GameWon`, `GameLost`) via `ref.listen` and translates them to `GameSound` events — the domain and application layers never import the concept of "sound".

## Game Mechanic

- The board is a tall, densely packed grid (it grows from ~6×8 up to ~11×15 with the level) of multi-cell arrows. Each arrow is a **path** (`Arrow.cells`, tail→head) that can **bend** in several directions — a straight arrow is just the degenerate case — with a `headDirection` by which its head leaves the board.
- Tapping an arrow runs [`RemoveArrowUseCase`](lib/application/use_cases/remove_arrow_use_case.dart), which checks whether the straight lane from the arrow's **head** to the edge (in `headDirection`) is clear of other arrows. The result is an `Either<DomainException, ArrowBoard>`, so "arrow not found" is distinguished from "move blocked".
- If the lane is clear, the arrow leaves the board **snake-style**: the head exits first and the body retracts along its own path (rendered by `ExitingArrowWidget` + `SnakeExitPainter`). The body only retracts over cells it already occupied, so it never collides with itself. If blocked, the move is rejected.
- Puzzles are **solvable by construction**: the generator ([`GraphBoardGenerator`](lib/infrastructure/generators/graph_board_generator.dart)) places each arrow only if it can exit given the ones already placed, so removing arrows in reverse placement order always clears the board. Difficulty — size, density, and maximum path length — is tuned in one place, [`LevelBlueprint.forLevel`](lib/domain/board/value_objects/level_blueprint.dart).
- The level is won when `ArrowBoard.isCleared` is true (`GameState` becomes `GameWon`).
- A level is lost (`GameState` becomes `GameLost`) either after 5 collisions (tapping blocked arrows, tracked by `StrikeCount`) or, on advanced levels, when the optional time limit runs out. The limit lives on the level model ([`LevelBlueprint.timeLimitSec`](lib/domain/board/value_objects/level_blueprint.dart)) and the countdown is driven by an **injectable clock** ([`ITicker`](lib/domain/game_core/services/i_ticker.dart)) — `SystemTicker` in the app, a fake clock in tests — with the remaining seconds exposed as `GamePlaying.remainingSeconds`.
- Moves are counted with `MoveCount` and can be undone through the `CommandInvoker`.
- **Audio feedback:** a sound fires on each arrow exit, collision, victory, and defeat, with looping background music during play. Music and SFX have **independent** mutes (plus a master mute) that **persist** across sessions, all behind the [`IAudioService`](lib/application/audio/i_audio_service.dart) facade. The sounds are original and procedurally synthesized (no sampled or copyrighted audio); the background music is a 16 s loop that is seamless by construction (frequencies quantized to multiples of `1/T`, periodic envelopes).

## Getting Started

### Prerequisites

- Flutter SDK with Dart >= 3.3
- A device or emulator (Android/iOS), or desktop/web target

### Install and run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Hive adapters + Riverpod codegen
flutter run
```

Re-run `build_runner` whenever you add or change files annotated with `@HiveType`, `@riverpod`, or `@JsonSerializable`.

### Docker (recommended for local dev — web target)

No Flutter SDK install required — serves the web build against the Dockerized backend. See `../README-docker.md` at the project root for the full stack (backend + frontend + database):

```bash
cd ..
docker compose up --build
```

Opens the game at `http://localhost:8080` in the browser. Hot reload isn't automatic in a container (Flutter only hot-reloads on a keypress, not on file save) — see `../README-docker.md` for how to attach and trigger it.

## Running Tests

```bash
flutter test       # unit & widget tests (AAA, mockito mocks) — 255 tests
flutter analyze    # static analysis — expected: 0 issues
```

## AI Usage Documentation

This client was built with AI assistance (Claude Code), and every significant fragment is recorded in [`AI_HISTORY.MD`](AI_HISTORY.MD) at the repository root. Each entry captures the task, the tool, the prompt, the resulting design decisions, and a field for manual edits by the team. It traces the build sublote by sublote, from the domain model through state management, persistence, the level generator, and the UI.

## Contributing

- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<scope>): <description>` in the imperative present, one significant fragment per commit (for example, `feat(front/application): add CommandInvoker`).
- **Branching**: feature work happens on a `feat/<name>` branch cut from `main`; this milestone lives on `feat/main-sprint`.
- **Pull requests**: open a PR against `main`, ensure `flutter test` and `flutter analyze` are green, and update `AI_HISTORY.MD` (and this README when public behavior changes) as part of the change.
- **CI/CD** is not configured yet; running the test suite and analyzer locally is the current gate.

## License

This is a private academic project (`pubspec.yaml` sets `publish_to: none`); no usage rights are granted by default. If the project is later opened up, add a `LICENSE` file (MIT is a sensible default) and update this section.
