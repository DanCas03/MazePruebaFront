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

**Tech stack:** Flutter (Dart >= 3.3), Riverpod for state and DI, Hive CE for local persistence, `dartz` for `Either`/`Option`, `equatable` for value equality, `logger` behind an AOP adapter, `build_runner` for code generation, and `flutter_test` + `mockito` for tests.

## Screenshots

Screenshots and a gameplay GIF are pending. To see the UI (dark-neon palette, glassmorphism panels, 3-D arrows, light/dark following the system theme), run the app with `flutter run`.

## Architecture

The dependency rule points inward: `infrastructure` and `presentation` depend on `application`, `application` depends on `domain`, and `domain` depends on nothing external.

```
lib/
├── domain/          Pure Dart — entities, value objects, exceptions, port interfaces
│   ├── arrows/      Arrow, ArrowBoard (aggregate root), ArrowId, ArrowLength, ILevelGenerator
│   ├── board/       LevelId, ILevelProgressRepository, IRemoteProgressRepository, ProgressReconciler
│   ├── game_core/   Position, Direction, MoveCount
│   ├── auth/        Email, AuthToken, IAuthTokenStorage (port)
│   └── core/        Domain exception hierarchy
├── application/     Use cases, Commands (undo), GameState (sealed), Riverpod Notifiers
│   ├── commands/    ICommand, CommandInvoker, RemoveArrowCommand
│   ├── state/       GameState / AuthState (sealed), GameController / AuthController (AsyncNotifier)
│   └── use_cases/   RemoveArrowUseCase, RestoreSessionUseCase (auto-login), LoginUseCase, RegisterUseCase, SyncProgressUseCase
├── infrastructure/  Hive persistence, secure token storage, RemoteAuthRepository, RemoteProgressRepository, GraphBoardGenerator (implements the domain ports)
├── presentation/    Screens, Widgets, Painters + providers/ (the only place infra is built)
│   └── auth/        Login/register screens (LoginScreen, RegisterScreen) and shared auth widgets
├── core/            Cross-cutting: aspects/ (logger), auth/ (AuthGate route guard), config/ (AppConfig), network/ (DioClient, AuthTokenInterceptor), theme/, router/
└── l10n/            i18n (front#4): app_en.arb / app_es.arb + generated AppLocalizations delegate (see Tooling → Localization)
```

The rule that keeps the boundary honest: `domain/` imports nothing from Flutter, Hive, or Riverpod, and every Riverpod provider that constructs a concrete `infrastructure/` class lives in `presentation/providers/`.

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
### Auth flow

Login and registration hit the backend at `POST /auth/login` and `POST /auth/register` (base URL configurable via `--dart-define=API_BASE_URL=...`, defaulting to `http://10.0.2.2:3000` for the Android emulator). A successful call persists the returned JWT through `IAuthTokenStorage` (front#14); `AuthGate`, sitting at the `MaterialApp`'s `home`, watches `authControllerProvider` and swaps from `LoginScreen` to the game flow (`HomeScreen`) as soon as the session becomes `Authenticated` — no manual navigation call is needed after login.

### Progress sync (front#18)

On the `Unauthenticated → Authenticated` transition (login or auto-login), `AuthGate` fires `SyncProgressUseCase.execute()` once via `ref.listen`. The use case pulls the server's progress (`GET /progress`) through the `IRemoteProgressRepository` port (`RemoteProgressRepository`, Dio-backed, in `infrastructure/`), reconciles it with the local Hive progress using the domain service `ProgressReconciler` — best score wins per level, and a level completed on either side stays completed — pushes the merged result back (`POST /progress`), and persists it locally through `ILevelProgressRepository`. The sync is fire-and-forget: network failures are logged (AOP) and swallowed, so a sync failure never blocks the auth guard or the game flow.

**Known limitation:** with "remember me" unchecked (`remember: false`), `AuthTokenInterceptor` does not yet sign requests from the in-memory session, so the sync's authenticated calls only succeed when "remember me" is checked, until front#16 fixes the interceptor.

### Localization (i18n · front#4)

The app ships Spanish (`es`, primary) and English (`en`), selected automatically from the device locale. Strings live in ARB files under [`lib/l10n/`](lib/l10n/) (`app_en.arb` is the key template, `app_es.arb` the Spanish translation); [`l10n.yaml`](l10n.yaml) drives `flutter gen-l10n`, which produces the `AppLocalizations` delegate. Because `flutter: generate: true` is set in `pubspec.yaml`, the delegate is regenerated on every `flutter pub get` / build, so the generated `lib/l10n/app_localizations*.dart` files are **not** committed (they are git-ignored).

Screens read strings through `AppLocalizations.of(context)`; there is no static string table. To add or change a string: edit both ARB files (same key), then run `flutter gen-l10n` (or `flutter pub get`). Messages with runtime values use ICU placeholders, e.g. `gameMoves(count)` → `"Moves: 3"` / `"Movimientos: 3"`.

## Design Patterns

| Pattern | Where | Problem it solves |
|---|---|---|
| **Command** | [`command.dart`](lib/application/commands/command.dart), [`command_invoker.dart`](lib/application/commands/command_invoker.dart), [`remove_arrow_command.dart`](lib/application/commands/remove_arrow_command.dart) | Models a move as a reversible operation. The invoker keeps history and delegates `undo` back to each command, so reversal logic lives with the operation. |
| **Aggregate Root** | [`arrow_board.dart`](lib/domain/arrows/entities/arrow_board.dart) | `ArrowBoard` is the single entry point to the arrows; lookups are private, so no consumer iterates the arrow list outside the root. |
| **Adapter** | [`logger_service_adapter.dart`](lib/core/aspects/logger_service_adapter.dart), [`secure_auth_token_repository.dart`](lib/infrastructure/repositories/secure_auth_token_repository.dart), [`remote_auth_repository.dart`](lib/infrastructure/repositories/remote_auth_repository.dart), [`remote_progress_repository.dart`](lib/infrastructure/repositories/remote_progress_repository.dart), [`auth_token_interceptor.dart`](lib/core/network/auth_token_interceptor.dart) | Wraps an external package/API behind a domain port, isolating the rest of the app from its concrete shape: `logger` behind `ILoggerService`, `flutter_secure_storage` behind `IAuthTokenStorage`, Dio behind `IAuthRepository` (`RemoteAuthRepository` translates HTTP/`DioException` into `AuthToken`/`AuthFailure`) and behind `IRemoteProgressRepository` (`RemoteProgressRepository` maps `LevelProgress` to/from the `/progress` JSON shape), and the token header injection behind a Dio `Interceptor`. |
| **AOP + Adapter** | [`auth_token_interceptor.dart`](lib/core/network/auth_token_interceptor.dart) | `AuthTokenInterceptor` (a Dio `Interceptor`) injects `Authorization: Bearer <token>` on every outgoing request by reading `IAuthTokenStorage`, so authenticated calls never repeat that boilerplate in application code. |
| **Strategy** | [`graph_board_generator.dart`](lib/infrastructure/generators/graph_board_generator.dart) | `GraphBoardGenerator` implements `ILevelGenerator` as a swappable generation algorithm (a DAG that guarantees solvability). |
| **Composition Root (DI)** | [`dependency_providers.dart`](lib/presentation/providers/dependency_providers.dart) | The one place concrete infrastructure is instantiated and injected as abstractions. |
| **Custom Painter** | [`arrow_painter.dart`](lib/presentation/game/painters/arrow_painter.dart) | Procedural rendering of arrows with a 3-D glow, avoiding image assets. |

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

## Game Mechanic

- The board is a tall, densely packed grid (it grows from ~6×8 up to ~11×15 with the level) of multi-cell arrows. Each arrow is a **path** (`Arrow.cells`, tail→head) that can **bend** in several directions — a straight arrow is just the degenerate case — with a `headDirection` by which its head leaves the board.
- Tapping an arrow runs [`RemoveArrowUseCase`](lib/application/use_cases/remove_arrow_use_case.dart), which checks whether the straight lane from the arrow's **head** to the edge (in `headDirection`) is clear of other arrows. The result is an `Either<DomainException, ArrowBoard>`, so "arrow not found" is distinguished from "move blocked".
- If the lane is clear, the arrow leaves the board **snake-style**: the head exits first and the body retracts along its own path (rendered by `ExitingArrowWidget` + `SnakeExitPainter`). The body only retracts over cells it already occupied, so it never collides with itself. If blocked, the move is rejected.
- Puzzles are **solvable by construction**: the generator ([`GraphBoardGenerator`](lib/infrastructure/generators/graph_board_generator.dart)) places each arrow only if it can exit given the ones already placed, so removing arrows in reverse placement order always clears the board. Difficulty — size, density, and maximum path length — is tuned in one place, [`LevelBlueprint.forLevel`](lib/domain/board/value_objects/level_blueprint.dart).
- The level is won when `ArrowBoard.isCleared` is true (`GameState` becomes `GameWon`).
- A level is lost (`GameState` becomes `GameLost`) either after 5 collisions (tapping blocked arrows, tracked by `StrikeCount`) or, on advanced levels, when the optional time limit runs out. The limit lives on the level model ([`LevelBlueprint.timeLimitSec`](lib/domain/board/value_objects/level_blueprint.dart)) and the countdown is driven by an **injectable clock** ([`ITicker`](lib/domain/game_core/services/i_ticker.dart)) — `SystemTicker` in the app, a fake clock in tests — with the remaining seconds exposed as `GamePlaying.remainingSeconds`.
- Moves are counted with `MoveCount` and can be undone through the `CommandInvoker`.

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
