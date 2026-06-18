# Arrow Maze — Flutter Client

A casual mobile puzzle game built with Flutter. The board is filled with multi-cell arrows of varying sizes and directions. Tap an arrow to slide it in its facing direction; if the path to the board edge is free of other arrows, the arrow exits the board. Clear every arrow to win the level.

---

## Architecture — Clean Mobile Architecture (Petros Efthymiou)

```
lib/
├── domain/            # Pure Dart — entities, value objects, domain exceptions, port interfaces
│   ├── arrows/        # Arrow aggregate (Arrow, ArrowBoard), ArrowId, ArrowLength, ILevelGenerator
│   ├── auth/          # Email value object
│   ├── board/         # ILevelProgressRepository, LevelId
│   └── game_core/     # Direction, Position, MoveCount value objects; domain exceptions
│
├── application/       # Use cases, Commands (undo/redo), GameState sealed class, Riverpod Notifiers
│   ├── commands/      # Command, CommandInvoker, RemoveArrowCommand (GoF Command pattern)
│   ├── state/         # GameState (sealed), GameController (Riverpod StateNotifier)
│   └── use_cases/     # RemoveArrowUseCase
│
├── infrastructure/    # Hive persistence, GraphBoardGenerator, data sources, repository impls
│   ├── data_sources/  # HiveLevelProgressDataSource
│   ├── generators/    # GraphBoardGenerator (implements ILevelGenerator)
│   ├── models/        # LevelProgressHiveModel (Hive type adapter, code-generated)
│   └── repositories/  # HiveProgressRepository (implements ILevelProgressRepository)
│
├── presentation/      # Screens, Widgets, Painters — depends only on application/ providers
│   ├── game/
│   │   ├── painters/  # ArrowPainter (procedural 3-D glow effect via CustomPainter)
│   │   ├── screens/   # GameScreen
│   │   └── widgets/   # ArrowWidget, BoardWidget, ExitingArrowWidget (exit animation)
│   ├── home/screens/  # HomeScreen
│   ├── level_selection/ # LevelSelectionScreen, VictoryScreen
│   └── providers/     # dependency_providers.dart (DI wiring), game_provider.dart
│
└── core/              # Cross-cutting concerns — never contains business logic
    ├── aspects/       # ILoggerService (port) + LoggerServiceAdapter (AOP logger)
    ├── router/        # AppRouter (go_router-style navigation)
    └── theme/         # AppColors, AppTheme
```

**Dependency rule**: `infrastructure` / `presentation` → `application` → `domain`. The `domain` layer is pure Dart and imports nothing external. `presentation` consumes only Riverpod providers from `application`; it never calls `infrastructure` or `domain` directly.

---

## Game Mechanic

- The board is a grid populated with multi-cell arrows (length 2+), each pointing in one of four directions (up, down, left, right).
- Tapping an arrow triggers `RemoveArrowUseCase`, which checks whether the cells between the arrow and the board edge (in the arrow's direction) are all empty.
- If the path is clear, the arrow slides off and exits — rendered by `ExitingArrowWidget` with a slide-out animation.
- If the path is blocked by another arrow, the move is rejected.
- The level is won when `ArrowBoard` contains no remaining arrows (`GameState.victory`).
- Moves are tracked via `MoveCount` and support undo via the `CommandInvoker`.

---

## Tech Stack

| Category | Technology |
|---|---|
| UI Framework | Flutter SDK (Dart >= 3.3) |
| State Management / DI | Riverpod (`flutter_riverpod`, `riverpod_annotation`) |
| Local Persistence | Hive CE (`hive_ce`, `hive_ce_flutter`) |
| Functional Utilities | `dartz` (Either / Option), `equatable` |
| HTTP Client | `dio` |
| Logging | `logger` + custom AOP adapter |
| Code Generation | `build_runner`, `riverpod_generator`, `hive_ce_generator` |
| Testing | `flutter_test`, `mockito` |

---

## Setup & Commands

```bash
# Install dependencies
flutter pub get

# Run code generators (Hive adapters, Riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Run the app (debug)
flutter run

# Run tests
flutter test

# Static analysis
flutter analyze
```

> Re-run `build_runner` whenever you add or modify files annotated with `@HiveType`, `@riverpod`, or `@JsonSerializable`.

---

## Project Structure at a Glance

```
MazePruebaFront/
├── lib/               # Application source (see architecture above)
├── test/              # Unit & widget tests (AAA pattern, mockito mocks)
├── assets/levels/     # Bundled level definition files
├── pubspec.yaml
└── README.md
```
