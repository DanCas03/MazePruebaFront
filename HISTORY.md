# Historial de cambios — Frontend (Flutter)

Bitácora **detallada y por pasos** de la construcción del cliente. Complementa el
`AI_HISTORY.MD` de la raíz (registro formal de aportes de IA) con el detalle
técnico específico del repositorio: qué se hizo en cada paso, qué archivos se
tocaron, por qué, y cómo verificarlo.

> Convención de fechas: el proyecto se desarrolló sobre la fecha base 2026-06-04.

---

## Hito 1 — Scaffold inicial de Clean Architecture (previo)

Estructura de carpetas por capas, `pubspec.yaml` con el stack (Riverpod, Hive CE,
Dio, logger…), dominio del juego original (celdas) y `main.dart` placeholder.
Punto de partida sobre el que se construyeron los hitos siguientes.

---

## Hito 2 — Sprint "demo Clean Architecture + DDD" (modelo de celdas)

> **Estado: SUPERSEDIDO por el Hito 3.** Se documenta para trazabilidad.

Primer sprint completo sobre el modelo "un jugador que se mueve por celdas":

- **Value Objects**: refuerzo de `Position` (`==`, `translate`) y `Direction`
  (extensión `DirectionBehavior` con `dx/dy/rotateClockwise/quarterTurns`); nuevos
  `LevelId`, `MoveCount`, `Email`.
- **Estado**: `BoardState` sealed (`BoardLoading/BoardPlaying/BoardCompleted`).
- **Persistencia (Adapter)**: `ILevelProgressRepository`, `LevelProgressEntry`,
  `LevelProgressHiveModel` (TypeAdapter manual) y `HiveProgressAdapter`.
- **AOP**: `ILoggerService` + `LoggerServiceAdapter`.
- **Riverpod**: `BoardController` (`Notifier`), providers de puertos overridables.
- **UI**: `HomeScreen`, `LevelSelectionScreen`, `GameScreen`, `VictoryScreen`,
  `BoardWidget`, tema, `main.dart` (raíz de composición Hive + overrides).
- **Tests AAA**: VOs, `BoardState`, `HiveProgressAdapter`, `BoardController`.

Verificación: `flutter analyze` limpio, 14/14 tests.

Decisiones de diseño relevantes (que sobreviven al rediseño):
- `Position` **no** valida no-negatividad (hay posiciones objetivo transitorias
  fuera del borde que el tablero descarta).
- TypeAdapter de Hive **escrito a mano** para compilar sin `build_runner`.
- Providers de puertos como **placeholders sobreescritos en `main.dart`** para que
  Aplicación no importe Infraestructura.

---

## Hito 3 — Rediseño del juego: rompecabezas de flechas multi-celda

Las reglas reales del juego son las del género *Arrows*: flechas multi-celda que
salen del tablero en línea recta si su recorrido está libre; se gana al limpiar el
tablero. Se **reemplazó por completo** el modelo de jugador/movimiento, conservando
la arquitectura (capas, VOs, Riverpod, Hive, AOP, tests).

### Paso 3.1 — Value Objects de flechas
- **Nuevos:** `domain/game_core/value_objects/arrow_id.dart` (`ArrowId`),
  `arrow_length.dart` (`ArrowLength`).

### Paso 3.2 — Entidades del dominio de flechas
- `domain/arrows/entities/arrow.dart` — `Arrow` paramétrica (`tail` + `direction` +
  `length` + `colorIndex`), con `cells`, `head` y `exitPath(w,h)`.
- `domain/arrows/entities/arrow_board.dart` — Aggregate Root `ArrowBoard`:
  `arrowAt`, `findById`, **`canExit`** (regla central), `removeArrow`/`addArrow`,
  `isCleared`, `copy`.

### Paso 3.3 — Generador con grafos
- `domain/arrows/services/i_level_generator.dart` — puerto `ILevelGenerator`.
- `infrastructure/generators/graph_board_generator.dart` — `GraphBoardGenerator`:
  colocación incremental donde el recorrido de salida de cada flecha nueva debe
  estar libre de las ya colocadas ⇒ grafo de dependencias **acíclico (DAG)** ⇒
  tablero **siempre resoluble**. Determinista por `LevelId` (RNG sembrado);
  dificultad escala con el nivel.

### Paso 3.4 — Aplicación
- `application/commands/remove_arrow_command.dart` — `RemoveArrowCommand`
  (reusa `ICommand`/`CommandInvoker` para *undo*).
- `application/use_cases/arrows/remove_arrow_use_case.dart` — `RemoveArrowUseCase`
  (resultado `removed`/`blocked`/`notFound`).
- `application/state/game_state.dart` — `GameState` sealed
  (`GameLoading/GamePlaying/GameWon`).
- `application/state/game_controller.dart` — `GameController` (`Notifier`).
- `application/providers/dependency_providers.dart` — se reemplaza
  `levelRepositoryProvider` por **`levelGeneratorProvider`**.
- `application/providers/game_controller_provider.dart` — `gameControllerProvider`.

### Paso 3.5 — Tema neón sobre navy
- `core/theme/app_theme.dart` — `AppColors` (paleta de flechas) + `AppTheme.dark`.

### Paso 3.6 — Presentación
- `presentation/game/painters/arrow_painter.dart` — `ArrowPainter` (trazo + punta +
  glow).
- `presentation/game/widgets/arrow_widget.dart` — `ArrowWidget` (shake al bloquear).
- `presentation/game/widgets/board_widget.dart` — `BoardWidget` (rejilla + flechas
  posicionadas por su rectángulo de celdas).
- `presentation/game/screens/game_screen.dart` — `GameScreen` con `switch`
  exhaustivo sobre el estado, barra superior, panel de victoria.
- `presentation/home/screens/home_screen.dart` y
  `presentation/level_selection/screens/level_selection_screen.dart` — rediseñadas;
  `kTotalLevels = 12`.
- `main.dart` — override de `levelGeneratorProvider` con `GraphBoardGenerator`; tema
  oscuro.

### Paso 3.7 — Eliminación del modelo anterior
Se borraron: celdas (`cell/arrow_cell/empty_cell/wall_cell/exit_cell/board`),
`cell_factory`, decoradores, `i_level_repository`, `player`, `move_command`,
`rotate_command`, los tres use cases antiguos, `board_state`/`board_controller`/
`board_controller_provider`, `level_repository_impl`, los widgets/pantallas de
juego viejos y sus tests, y la excepción huérfana `unknown_cell_type_exception`.

### Paso 3.8 — Tests del nuevo juego
- `test/domain/arrows/arrow_board_test.dart` — bloqueo/salida, `arrowAt`, limpieza.
- `test/infrastructure/generators/graph_board_generator_test.dart` — solubilidad
  (solver voraz Kahn) en 20 niveles, determinismo, no solapamiento.
- `test/application/state/game_controller_test.dart` — jugar/bloqueo/victoria/
  persistencia.

Verificación del hito: `flutter analyze` sin issues, **21/21** tests.

---

## Hito 4 — Mejoras de UI (paleta madura + animaciones)

### Paso 4.1 — Paleta madura
- `core/theme/app_theme.dart` — tonos joya desaturados (esmeralda, teal, rosa,
  ámbar, terracota, violeta, índigo, rojo apagado) sobre índigo profundo;
  `AppColors.victory`. `arrow_painter.dart` — glow y brillo suavizados.

### Paso 4.2 — Animación de acierto (la flecha sale disparada)
- `core/constants/durations.dart` — `kArrowExitDuration`, `kBlockedShakeDuration`.
- `remove_arrow_use_case.dart` — `RemoveArrowResult` ahora incluye la **flecha**
  afectada.
- `game_state.dart` — `GamePlaying` añade `exitingArrow` + `exitNonce`.
- `game_controller.dart` — al sacar una flecha emite `exitingArrow` para animarla y
  **difiere la victoria** (`_scheduleWin`, espera `kArrowExitDuration`) para que la
  última flecha termine de salir antes de mostrar el panel.
- `presentation/game/widgets/exiting_arrow_widget.dart` — **nuevo** overlay
  `IgnorePointer` que desliza la flecha en su dirección (`Curves.easeIn`) y la
  desvanece.
- `board_widget.dart` — `Clip.none` para dejar que la flecha saliente cruce el
  borde; renderiza el overlay de salida; cálculo de rectángulo reutilizable.

### Paso 4.3 — Más animaciones
- `game_screen.dart` — `AnimatedSwitcher` (fade+scale) entre estados; trofeo de
  victoria con `Curves.elasticOut`.
- `home_screen.dart` — logo `_LogoArrows` con **flotación perpetua**
  (`AnimationController` en bucle, bob senoidal con desfases).

### Paso 4.4 — Test y verificación
- `test/application/state/game_controller_test.dart` — actualizado para la
  **victoria diferida** (se espera la duración de la animación).
- Verificación: `flutter analyze` sin issues, **21/21** tests.

---

## Limitación transversal

El entorno de desarrollo **no dispone de generación de imágenes**, por lo que el
flujo "image-first" de las skills de diseño no pudo ejecutarse literalmente. Se
usaron las **capturas aportadas por el usuario** como referencia visual, aplicando
los principios de dichas skills (fondo profundo, flechas redondeadas, barra
superior limpia, paleta controlada, micro-motion).
