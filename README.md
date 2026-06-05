# Arrow Maze — Frontend (Flutter)

Cliente del juego casual **Arrow Maze**: un rompecabezas en el que el tablero
se llena de flechas multi-celda de distintos tamaños y direcciones. Al tocar una
flecha, esta intenta **salir del tablero en línea recta**; solo lo logra si su
recorrido hasta el borde está libre de otras flechas. **Se gana al limpiar el
tablero**, sacando las flechas una a una.

Este documento describe la arquitectura, la estructura de carpetas y **cómo
funciona cada parte del código**, para entender y corregir la app lo más rápido
posible.

---

## Índice

1. [Stack técnico](#stack-técnico)
2. [Reglas del juego](#reglas-del-juego)
3. [Arquitectura (Clean + DDD)](#arquitectura-clean--ddd)
4. [Estructura de carpetas](#estructura-de-carpetas)
5. [Capa de Dominio](#capa-de-dominio)
6. [El generador de tableros (grafos / DAG)](#el-generador-de-tableros-grafos--dag)
7. [Capa de Aplicación (estado y casos de uso)](#capa-de-aplicación-estado-y-casos-de-uso)
8. [Capa de Infraestructura](#capa-de-infraestructura)
9. [Capa de Presentación (UI y animaciones)](#capa-de-presentación-ui-y-animaciones)
10. [Inyección de dependencias (composición)](#inyección-de-dependencias-composición)
11. [Flujos de ejecución end-to-end](#flujos-de-ejecución-end-to-end)
12. [Patrones de diseño aplicados](#patrones-de-diseño-aplicados)
13. [Pruebas](#pruebas)
14. [Comandos de desarrollo](#comandos-de-desarrollo)
15. [Convenciones](#convenciones)
16. [Puntos de extensión / deuda conocida](#puntos-de-extensión--deuda-conocida)

---

## Stack técnico

| Área | Tecnología |
|------|-----------|
| UI | Flutter (Material 3) |
| Estado / DI | Riverpod (`flutter_riverpod`, `Notifier`/`NotifierProvider`) |
| Persistencia local | Hive CE (`hive_ce`, `hive_ce_flutter`) |
| Logging | paquete `logger` (envuelto por un adaptador) |
| Pruebas | `flutter_test` |

> Otras dependencias declaradas en `pubspec.yaml` (`dio`, `sqflite`, `get_it`,
> `dartz`, `equatable`) están instaladas para fases futuras y **no se usan aún**.

---

## Reglas del juego

- El tablero es una cuadrícula cuadrada llena de **flechas**.
- Cada flecha **ocupa varias celdas** en una fila o columna y **apunta** a uno de
  los 4 lados (arriba/abajo/izquierda/derecha).
- Al **tocar** una flecha, esta intenta salir del tablero **en línea recta** en la
  dirección a la que apunta.
- Una flecha **solo puede salir si todas las celdas de su recorrido** (desde su
  punta hasta el borde) **están libres**. Si otra flecha la bloquea, no sale.
- **Se gana al vaciar el tablero.** Las flechas salen **una a una** con cada toque,
  liberando espacio para las demás.
- El número de **movimientos** (flechas sacadas) se guarda como mejor marca por
  nivel.

---

## Arquitectura (Clean + DDD)

Cuatro capas con la **regla de dependencia** apuntando hacia adentro:

```
Presentation ──▶ Application ──▶ Domain
Infrastructure ─▶ Application (implementa puertos)
Infrastructure ─▶ Domain (usa entidades/VOs)
Core ───────────▶ transversal (lo puede usar cualquier capa)
```

Reglas estrictas que se cumplen en el código:

- `domain/` es **Dart puro**: no importa `package:flutter/...`, ni Riverpod, ni Hive.
- `application/` no importa `presentation/` ni `infrastructure/`.
- Las implementaciones concretas (Hive, generador) viven en `infrastructure/` y se
  inyectan a través de **puertos** (interfaces) sobreescribiendo providers en
  `main.dart`. Así la app permanece desacoplada de las tecnologías concretas.

**DDD:** el dominio evita la *primitive obsession* usando **Value Objects** (VO)
inmutables con igualdad por valor en lugar de `int`/`String` sueltos.

---

## Estructura de carpetas

```
lib/
├── main.dart                         ← Raíz de composición (Hive + ProviderScope + MaterialApp)
│
├── domain/                           ← CAPA 1 — reglas puras (sin Flutter)
│   ├── arrows/
│   │   ├── entities/
│   │   │   ├── arrow.dart            ← Entidad Arrow (multi-celda, head, exitPath)
│   │   │   └── arrow_board.dart      ← Aggregate Root: tablero + reglas (canExit…)
│   │   └── services/
│   │       └── i_level_generator.dart← Puerto: genera el tablero de un nivel
│   ├── board/
│   │   ├── entities/level_progress_entry.dart   ← Progreso de un nivel (VOs)
│   │   └── repositories/i_level_progress_repository.dart ← Puerto de persistencia
│   ├── game_core/value_objects/      ← Value Objects
│   │   ├── position.dart             ← Position {x,y} (== , translate)
│   │   ├── direction.dart            ← enum Direction + DirectionBehavior (dx,dy,…)
│   │   ├── level_id.dart             ← LevelId
│   │   ├── move_count.dart           ← MoveCount
│   │   ├── arrow_id.dart             ← ArrowId
│   │   └── arrow_length.dart         ← ArrowLength
│   ├── auth/value_objects/email.dart ← Email VO (para auth futura)
│   └── core/exceptions/              ← Excepciones de dominio
│
├── application/                      ← CAPA 2 — orquestación
│   ├── commands/                     ← Patrón Command (undo)
│   │   ├── command.dart              ← ICommand
│   │   ├── command_invoker.dart      ← Historial + undo
│   │   └── remove_arrow_command.dart ← Sacar/reinsertar flecha
│   ├── use_cases/arrows/remove_arrow_use_case.dart  ← Regla "intentar sacar flecha"
│   ├── state/
│   │   ├── game_state.dart           ← sealed: Loading/Playing/Won
│   │   └── game_controller.dart      ← Notifier (orquesta todo)
│   └── providers/
│       ├── dependency_providers.dart ← Providers de los PUERTOS (overridables)
│       ├── game_controller_provider.dart
│       └── level_progress_providers.dart
│
├── infrastructure/                   ← CAPA 4 — implementaciones concretas
│   ├── generators/graph_board_generator.dart       ← ILevelGenerator (grafos/DAG)
│   ├── models/level_progress_hive_model.dart       ← Modelo Hive + TypeAdapter manual
│   └── repositories_impl/hive_progress_adapter.dart← ILevelProgressRepository (Hive)
│
├── core/                             ← Transversal
│   ├── aspects/                      ← AOP de logging
│   │   ├── i_logger_service.dart     ← ILoggerService (puerto)
│   │   └── logger_service_adapter.dart ← Adapter del paquete `logger`
│   ├── theme/app_theme.dart          ← AppColors (paleta) + AppTheme.dark
│   └── constants/durations.dart      ← Duraciones de animación compartidas
│
└── presentation/                     ← CAPA 3 — UI Flutter
    ├── home/screens/home_screen.dart
    ├── level_selection/screens/level_selection_screen.dart
    └── game/
        ├── screens/game_screen.dart  ← Pantalla principal (AnimatedSwitcher por estado)
        ├── widgets/
        │   ├── board_widget.dart      ← Dibuja la cuadrícula + flechas
        │   ├── arrow_widget.dart      ← Flecha interactiva (shake al bloquear)
        │   └── exiting_arrow_widget.dart ← Animación de salida (acierto)
        └── painters/arrow_painter.dart   ← Pinta la flecha neón (trazo + punta + glow)
```

---

## Capa de Dominio

### Value Objects (`domain/game_core/value_objects/`)

Todos son **inmutables** y comparan **por valor** (`==`/`hashCode`).

| VO | Propósito | Notas clave |
|----|-----------|-------------|
| `Position {x,y}` | Coordenada de celda | `translate(Direction)` devuelve una nueva posición desplazada por el vector de la dirección. **No** valida no-negatividad a propósito (hay cálculos de posición transitorios fuera del borde que el tablero descarta). |
| `Direction` | enum `{up,down,left,right}` | La **extensión `DirectionBehavior`** concentra todo el comportamiento: `dx`/`dy` (vector de desplazamiento, eje Y crece hacia abajo), `rotateClockwise`, `quarterTurns` (para rotar el ícono en la UI) y `fromString`. Evita `switch (direction)` disperso. |
| `LevelId` | Identificador de nivel | `assert(value > 0)`. Siembra el generador (mismo id ⇒ mismo tablero). |
| `MoveCount` | Conteo de movimientos | `assert(value >= 0)`, `increment()` inmutable. |
| `ArrowId` | Identidad de una flecha | Usado para tocar/buscar/animar una flecha concreta. |
| `ArrowLength` | Tamaño (nº de celdas) | `assert(value >= 1)`. |

### Entidad `Arrow` (`domain/arrows/entities/arrow.dart`)

Modela una flecha de forma **paramétrica**: `tail` (celda trasera) + `direction`
(dirección de salida) + `length` + `colorIndex` (índice de paleta, dato puro para
no acoplar el dominio a Flutter).

- `cells` → lista de celdas que ocupa (de la cola a la punta).
- `head` → celda delantera (la punta, por donde sale primero).
- `exitPath(width, height)` → celdas que debe atravesar para salir (desde delante
  de la punta hasta cruzar el borde). **Si alguna está ocupada por otra flecha, el
  movimiento está bloqueado.**
- Igualdad por `id`.

### Aggregate Root `ArrowBoard` (`domain/arrows/entities/arrow_board.dart`)

Posee las flechas y centraliza las reglas del tablero. Nadie manipula la lista de
flechas directamente.

- `arrowAt(Position)` → qué flecha ocupa una celda (o `null`).
- `findById(ArrowId)`.
- **`canExit(Arrow)`** → la **regla central**: `true` si todas las celdas del
  `exitPath` de la flecha están libres de otras flechas.
- `removeArrow(id)` / `addArrow(arrow)` → para sacar/reinsertar (este último lo usa
  el *undo*).
- `isCleared` → `true` cuando no quedan flechas (condición de victoria).
- `copy()` → copia para simulaciones/tests sin mutar el original.

### Progreso (`domain/board/`)

- `LevelProgressEntry` → `{ levelId, isCompleted, bestMoveCount }` (todo VOs).
  `withBestMove(candidate)` devuelve una copia conservando la **menor** marca.
- `ILevelProgressRepository` → puerto de persistencia: `loadProgress`,
  `saveProgress`, `loadAllProgress`.

> Nota: estos dos archivos viven bajo `board/` por herencia histórica del
> proyecto. Funcionalmente pertenecen al progreso del juego (ver
> [deuda conocida](#puntos-de-extensión--deuda-conocida)).

---

## El generador de tableros (grafos / DAG)

Archivo: `infrastructure/generators/graph_board_generator.dart` (implementa el
puerto `domain/arrows/services/i_level_generator.dart`).

**Objetivo:** generar tableros **siempre resolubles** sin necesidad de un
solucionador. Se logra con **construcción inversa** basada en un grafo de
dependencias:

1. Se colocan flechas **una a una** en posiciones aleatorias (orientación,
   longitud y dirección al azar).
2. Una flecha nueva solo se acepta si:
   - sus celdas **no se solapan** con las ya colocadas, **y**
   - su **recorrido de salida está libre** de las flechas ya colocadas.
3. Esa segunda condición define un grafo dirigido "A bloquea a B" donde **cada
   arista va de una flecha más antigua a una más nueva** ⇒ el grafo es
   **acíclico (DAG)**.
4. Por tanto, el **orden de salida = orden inverso de colocación** siempre resuelve
   el tablero. (Un solucionador voraz tipo Kahn también lo limpia siempre, lo que
   verifican los tests.)

Otros detalles:

- **Determinismo:** el `Random` se siembra con `levelId.value`, de modo que un
  nivel produce **siempre el mismo tablero** (clave para que la "mejor marca" tenga
  sentido y para reproducir bugs).
- **Dificultad:** el tamaño del tablero crece con el nivel
  (`size = min(5 + level~/2, 9)`) y se rellena hasta ~55 % de celdas.
- El `colorIndex` de cada flecha se elige dentro de una paleta de 8 (la UI hace el
  módulo).

---

## Capa de Aplicación (estado y casos de uso)

### `RemoveArrowUseCase` (`application/use_cases/arrows/`)

Regla de negocio "intentar sacar una flecha":

- Busca la flecha; si no existe → `notFound`.
- Si **no puede salir** (`board.canExit == false`) → `blocked` (devuelve la flecha
  para que la UI la sacuda).
- Si puede → ejecuta un `RemoveArrowCommand` a través del `CommandInvoker` (lo que
  habilita el *undo*) y devuelve `removed` con `boardCleared` y la flecha sacada.

`RemoveArrowResult` lleva `{ outcome, boardCleared, arrow }`.

### Estado `GameState` (`application/state/game_state.dart`)

`sealed class` para `switch` exhaustivo en la UI:

- `GameLoading` — generando el tablero.
- `GamePlaying { board, movesUsed, canUndo, blockedArrow, blockedNonce, exitingArrow, exitNonce }`
  - `blockedArrow` + `blockedNonce` → feedback de **shake** (el nonce cambia para
    re-disparar la animación aunque sea la misma flecha).
  - `exitingArrow` + `exitNonce` → flecha que **acaba de salir** (ya retirada del
    `board`); la UI la anima saliendo de la pantalla.
- `GameWon { moves }` — tablero limpio.

### `GameController` (`application/state/game_controller.dart`)

`Notifier<GameState>`. Resuelve sus dependencias (puertos) en `build()` vía
`ref.read`. **No importa Flutter Material.** Mantiene el estado con alcance de
partida: `board`, `CommandInvoker`, `RemoveArrowUseCase`, contadores y *nonces*.

Métodos:

- `loadLevel(LevelId)` → genera el tablero con el `ILevelGenerator` y emite
  `GamePlaying`.
- `onArrowTapped(ArrowId)` → ejecuta el caso de uso y:
  - `removed` → incrementa movimientos y `exitNonce`, emite `GamePlaying` con
    `exitingArrow` (para animar la salida). Si el tablero quedó limpio, **difiere la
    victoria** con `_scheduleWin()` (espera `kArrowExitDuration`) para que la última
    flecha termine de animar; luego emite `GameWon` y persiste el progreso.
  - `blocked` → incrementa `blockedNonce` y emite `GamePlaying` con `blockedArrow`
    (shake).
  - `notFound` → ignora.
- `onUndo()` → `CommandInvoker.undoLastCommand()` (reinserta la última flecha).
- `onRestart()` → regenera el mismo nivel (determinista).

### Providers (`application/providers/`)

- `dependency_providers.dart` → declara los **puertos** como providers
  placeholder (`levelGeneratorProvider`, `levelProgressRepositoryProvider`,
  `loggerServiceProvider`). Se **sobreescriben en `main.dart`**. Así Aplicación no
  importa Infraestructura.
- `game_controller_provider.dart` → `gameControllerProvider` (lo que observa la UI).
- `level_progress_providers.dart` → `levelProgressListProvider` (FutureProvider con
  todo el progreso; la selección de niveles lo `watch`ea y se invalida tras ganar).

---

## Capa de Infraestructura

- **`HiveProgressAdapter`** (Patrón Adapter) implementa `ILevelProgressRepository`
  envolviendo una `Box` de Hive. Recibe la box ya abierta por constructor.
- **`LevelProgressHiveModel`** es el modelo de persistencia (solo primitivos) con un
  **`TypeAdapter` escrito a mano** (mismo formato binario que generaría
  `hive_ce_generator`, pero **sin paso de code-gen**). Sus `toEntry()`/`fromEntry()`
  son los *mappers* dominio↔persistencia: los VOs nunca llegan a la base de datos.
- **`GraphBoardGenerator`** ver [sección del generador](#el-generador-de-tableros-grafos--dag).

---

## Capa de Presentación (UI y animaciones)

### `ArrowPainter` (`painters/arrow_painter.dart`)

`CustomPainter` que dibuja la flecha **dentro del rectángulo del widget**, según su
dirección: trazo redondeado (cap round) + **punta triangular** + una capa de
**glow** (blur) suave + un brillo interior. El estilo neón maduro vive aquí.

### `ArrowWidget` (`widgets/arrow_widget.dart`)

`StatefulWidget` interactivo:

- `GestureDetector` opaco → `onTap`.
- Si `isBlocked` y cambia `blockedNonce`, dispara un **shake** (oscilación senoidal
  amortiguada en la dirección de la flecha) con un `AnimationController`.

### `ExitingArrowWidget` (`widgets/exiting_arrow_widget.dart`)

Overlay **cosmético** (`IgnorePointer`) de la animación de **acierto**: la flecha
se **desliza en su dirección** (`Curves.easeIn`, "sale disparada") por `travel`
píxeles y se **desvanece**. El dominio ya retiró la flecha; este widget solo la
"despide". Se re-dispara con `exitNonce`.

### `BoardWidget` (`widgets/board_widget.dart`)

Calcula el tamaño de celda con `LayoutBuilder` y arma un `Stack` (con
`clipBehavior: Clip.none` para dejar que la flecha saliente cruce el borde):

1. Fondo: panel redondeado + rejilla sutil (`_GridPainter`).
2. Cada flecha del `board` → un `ArrowWidget` posicionado en su rectángulo de celdas.
3. Si hay `exitingArrow` → un `ExitingArrowWidget` en la posición original de esa
   flecha.

### `GameScreen` (`screens/game_screen.dart`)

`ConsumerStatefulWidget` que recibe un `LevelId`:

- En `initState` llama `loadLevel(levelId)` (fuera del ciclo de build).
- `ref.watch(gameControllerProvider)` y un **`switch` exhaustivo** sobre el estado:
  - `GameLoading` → spinner.
  - `GamePlaying` → `_PlayingView`: `_TopBar` (atrás, píldora de nivel, undo,
    reiniciar) + `BoardWidget`.
  - `GameWon` → `_WonView`: panel de victoria (trofeo con rebote `elasticOut`,
    movimientos, botones siguiente/reintentar/volver).
- Todo el `switch` va dentro de un **`AnimatedSwitcher`** (fade + scale) para animar
  las transiciones entre estados.

### `HomeScreen` y `LevelSelectionScreen`

- **Home:** fondo con gradiente radial, logo `_LogoArrows` con **flotación
  perpetua** (3 barras que se mecen con desfases) y botón "JUGAR".
- **Selección:** grilla de `kTotalLevels` (12) niveles; lee el progreso para marcar
  los completados (borde de color + "★ <mejor marca>"). Al tocar un nivel navega a
  `GameScreen(LevelId(n))`.

---

## Inyección de dependencias (composición)

`main.dart` es la **única** parte que conoce la Capa 4:

1. `Hive.initFlutter()` + registra `LevelProgressHiveModelAdapter` + abre la box
   `level_progress`.
2. `ProviderScope(overrides: [...])` sobreescribe los puertos con sus
   implementaciones concretas:
   - `levelGeneratorProvider` → `GraphBoardGenerator()`
   - `levelProgressRepositoryProvider` → `HiveProgressAdapter(box)`
   - `loggerServiceProvider` → `LoggerServiceAdapter()`
3. `MaterialApp(theme: AppTheme.dark, home: HomeScreen())`.

---

## Flujos de ejecución end-to-end

**Arranque:** `main()` → Hive listo → `ProviderScope` con overrides → `HomeScreen`.

**Entrar a un nivel:**
`HomeScreen` → "JUGAR" → `LevelSelectionScreen` → tocar nivel N →
`GameScreen(LevelId(N))` → `initState` → `GameController.loadLevel` →
`GraphBoardGenerator.generate` → `GamePlaying`.

**Tocar una flecha:**
`ArrowWidget.onTap` → `GameController.onArrowTapped(id)` →
`RemoveArrowUseCase.execute` → `ArrowBoard.canExit`:
- **libre** → comando de salida (vía `CommandInvoker`) → `GamePlaying` con
  `exitingArrow` (animación de salida) → si `isCleared`, tras `kArrowExitDuration`
  → `GameWon` + persistencia Hive.
- **bloqueada** → `GamePlaying` con `blockedArrow` (shake).

**Deshacer:** `_TopBar` undo → `GameController.onUndo` →
`CommandInvoker.undoLastCommand` → `ArrowBoard.addArrow` → `GamePlaying`.

**Persistencia:** al ganar, `GameController` lee el progreso previo, conserva la
mejor marca (`withBestMove`) y lo guarda con `HiveProgressAdapter`. La selección de
niveles invalida `levelProgressListProvider` para refrescar.

---

## Patrones de diseño aplicados

| Patrón | Dónde | Para qué |
|--------|-------|----------|
| **Aggregate Root (DDD)** | `ArrowBoard` | Posee las flechas y centraliza invariantes/reglas. |
| **Value Object (DDD)** | `domain/game_core/value_objects/` | Sin *primitive obsession*; invariantes encapsulados. |
| **Command** | `application/commands/` | Encapsula la salida de flecha con `undo`. |
| **Strategy / construcción por grafo** | `GraphBoardGenerator` | Genera tableros resolubles (DAG). |
| **Adapter** | `HiveProgressAdapter`, `LoggerServiceAdapter` | Envuelven Hive y `logger` tras puertos internos. |
| **Repository / Port (DIP)** | `ILevelProgressRepository`, `ILevelGenerator`, `ILoggerService` | Desacoplan dominio/aplicación de la tecnología. |
| **Observer** | `Notifier` + Riverpod | Notifica a la UI los cambios de estado. |
| **AOP** | `ILoggerService`/`LoggerServiceAdapter` | Logging como *cross-cutting concern* fuera de la lógica. |

---

## Pruebas

`test/` (patrón **AAA** Arrange–Act–Assert):

| Archivo | Qué valida |
|---------|------------|
| `domain/value_objects/value_objects_test.dart` | Igualdad/validación de VOs, `translate`, rotación de `Direction`. |
| `domain/arrows/arrow_board_test.dart` | Bloqueo/salida (`canExit`), `arrowAt`, limpieza del tablero. |
| `infrastructure/generators/graph_board_generator_test.dart` | **Solubilidad** (solver voraz tipo Kahn) en 20 niveles, **determinismo** por `LevelId`, no solapamiento. |
| `infrastructure/repositories_impl/hive_progress_adapter_test.dart` | Round-trip de persistencia con una box temporal real. |
| `application/state/game_controller_test.dart` | Transiciones: jugar, bloqueo, victoria diferida + persistencia. |
| `widget_test.dart` | Arranque de `ArrowMazeApp`. |

Estado actual: **21/21** en verde y `flutter analyze` sin issues.

---

## Comandos de desarrollo

```bash
flutter pub get          # instalar dependencias
flutter run              # ejecutar la app (requiere dispositivo/emulador)
flutter analyze          # análisis estático
flutter test             # correr todas las pruebas
```

---

## Convenciones

- Archivos `snake_case`, clases `PascalCase`, providers `camelCase`.
- `domain/` nunca importa Flutter.
- Un caso de uso / un archivo; los widgets de presentación son lo más "tontos"
  posible (reciben datos + callbacks).
- Commits: Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`…).

---

## Puntos de extensión / deuda conocida

- **`LevelProgressEntry` e `ILevelProgressRepository` bajo `domain/board/`**: nombre
  de carpeta heredado del modelo anterior (celdas). Conviene moverlos a
  `domain/progress/` o `domain/arrows/` en una limpieza futura.
- **Etapa "híbrida" pendiente**: sincronizar progreso/puntuaciones con el backend
  (modelo `Score` + endpoints). Hoy el progreso es 100 % local (Hive).
- **VOs de auth** (`Email`) y excepciones asociadas están listos para las pantallas
  de login/registro futuras.
- **Ajustes de animación**: duración/curva/`travel` de la salida en
  `core/constants/durations.dart` y `BoardWidget`/`ExitingArrowWidget`.
