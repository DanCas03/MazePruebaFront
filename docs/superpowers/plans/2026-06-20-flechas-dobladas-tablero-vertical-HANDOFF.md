# HANDOFF — Ejecución del plan "Flechas dobladas, tablero vertical denso y salida serpiente"

> Documento de traspaso para que **otro agente actúe como ORQUESTADOR** y ejecute el plan
> con **subagentes** (subagent-driven). Léelo entero antes de tocar código.

## Qué vas a hacer

Orquestar, tarea por tarea, la implementación del plan que convierte la flecha de "recta" a
"camino" (dobla en varias direcciones), puebla el tablero con una curva vertical-densa y le da
una salida "serpiente" (cabeza primero). Conservas la arquitectura Clean Mobile actual.

## Documentos fuente (léelos primero, en este orden)

1. **Spec (qué y por qué):** `docs/superpowers/specs/2026-06-20-flechas-dobladas-tablero-vertical-design.md`
2. **Plan (cómo, paso a paso):** `docs/superpowers/plans/2026-06-20-flechas-dobladas-tablero-vertical.md`
3. **Este handoff (cómo orquestar + entorno).**

El plan es la fuente de verdad de ejecución: 6 tareas, cada step con código real, paths exactos y
comandos con su salida esperada. Sus pasos de prueba son **prompts de delegación**, no código.

## Método de ejecución (IMPORTANTE)

- Usa la skill **`superpowers:subagent-driven-development`**: un subagente fresco por tarea + revisión
  en dos etapas entre tareas. El usuario eligió este modo y pidió que **otro agente** orqueste.
- **Por cada tarea del plan:**
  1. Despacha un **subagente de implementación** que ejecute los steps de **código de producción**
     de esa tarea (con el código exacto del plan). Indícale el directorio `MazePruebaFront/` y la rama.
  2. Despacha un **subagente `arrowmaze-qa`** (o `qa-engineer`) con el **prompt "Delegar tests"** de
     esa tarea, verbatim, para que escriba/migre las pruebas (AAA, mockeando externos).
  3. Corre `flutter test` y `flutter analyze`; exige **verde** antes de continuar.
  4. **Revisión de dos etapas** (la del skill) y **commit** de la tarea (un commit por fragmento).
  5. Marca los checkbox `- [ ]` de esa tarea en el plan.
- Ejecuta las tareas **en orden (1 → 6)**.
- **Checkpoint con el usuario al terminar cada tarea** (resumen breve + resultado de `flutter test`).
- **Disciplina:** los subagentes NO borran aserciones para "que pase". Si algo no cuadra, se detienen
  y diagnostican (`superpowers:systematic-debugging`).

## Entorno

- **Directorio de trabajo:** `MazePruebaFront/` (artefacto Flutter). Es su **propio repo git** en la rama
  **`feat/main-sprint`**. La carpeta raíz `ArrowMaze/` **NO** es git.
- **Package:** `flutter_arrow_maze` (todos los imports de test usan este prefijo).
- **Shell:** PowerShell en Windows. (El working dir del shell puede reiniciarse a la raíz; haz `cd MazePruebaFront` al inicio de cada sesión de shell.)
- **Si usas worktrees aislados por subagente:** OJO con el WIP del pre-flight (abajo) — un worktree
  creado desde HEAD **no** verá los cambios sin commitear. Por eso el pre-flight los commitea primero.

### Pre-flight (ANTES de la Task 1) — OBLIGATORIO

El plan **depende de `ArrowBoard.overlaps`**, que ahora mismo está **sin commitear** en el árbol.
Estado actual de `git status -s`:

```
 M lib/domain/arrows/entities/arrow_board.dart        <- añade overlaps()  [DEPENDENCIA del plan]
 M lib/infrastructure/generators/graph_board_generator.dart  <- usa overlaps()  [DEPENDENCIA del plan]
 M lib/presentation/home/screens/home_screen.dart     <- rediseño de la home  [NO relacionado]
```

1. **Commitea la prevención de solapamiento como su propio fragmento** (es prerrequisito del plan):

   ```bash
   cd MazePruebaFront
   git add lib/domain/arrows/entities/arrow_board.dart lib/infrastructure/generators/graph_board_generator.dart
   git commit -m "feat(front/domain): prevent overlapping arrows on placement

   Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
   ```

   (Añade también su entrada en `AI_HISTORY.MD` si sigues CLAUDE.md al pie.)

2. **Deja `lib/presentation/home/screens/home_screen.dart` fuera** de estos commits (es un rediseño de
   la home no relacionado con este sprint). Si estorba para un árbol limpio, `git stash push` solo ese
   archivo, o coordínalo aparte con el usuario. No lo descartes.

3. Foto inicial:

   ```bash
   flutter pub get
   flutter analyze     # debería quedar limpio tras el commit del paso 1
   flutter test        # debería pasar (suite verde)
   ```

### Comandos clave

- Un test: `flutter test <ruta>`  ·  Todos: `flutter test`  ·  Lint: `flutter analyze`
- **Codegen de mocks (mockito):** `dart run build_runner build --delete-conflicting-outputs`
  - **Obligatorio en Task 3** (Step 3): se cambia la firma de `ILevelGenerator.generate`
    (añade `required int maxPathLen`) y `game_controller_test.dart` usa `@GenerateMocks([ILevelGenerator, ...])`.

## Reglas de commits

1. **Un commit por tarea** (fragmento). No acumular varias tareas en un commit.
2. Cada commit incluye una entrada nueva en `MazePruebaFront/AI_HISTORY.MD` (plantilla de CLAUDE.md:
   Fecha 2026-06-20, Tarea, Herramienta de IA, Prompt, Resultado).
3. **Conventional Commits** con el mensaje que indica cada Task; termina el mensaje con el trailer
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
4. Si una tarea cambia superficie pública (mecánica/arquitectura), actualiza `README.md` (Task 6 lo hace).

## Cosas ya verificadas (no las re-descubras)

- Package = `flutter_arrow_maze`.
- **El render y el hit-testing ya son agnósticos a la forma:** `ArrowPainter` dibuja una polilínea
  sobre `cells`; `BoardWidget` hace hit-testing por celda (`board.arrowAt(pos)`). Por eso las flechas
  dobladas "se dibujan y se tocan" sin tocar esa capa.
- **La mecánica serpiente reusa la salida actual:** `Arrow.exitPath`/`ArrowBoard.canExit` siguen siendo
  el rayo recto desde la cabeza al borde. El cuerpo se retrae por su propio camino; la solubilidad por
  construcción (DAG: orden inverso de colocación), el determinismo por seed y el undo se conservan.
- `Position({row,col})` **no** es `const` (valida en el cuerpo). `ArrowId(String)` **sí** es `const`.
  `Arrow({...})` es `const`; `Arrow.straight({...})` es un **factory** (no const).
- **mockito:** si un argumento de `verify`/`when` es matcher (`any`/`argThat`), TODOS deben serlo.

## Expectativas de estado intermedio

- A diferencia de sprints anteriores, **cada tarea queda verde** (compila + tests pasan + analyze
  limpio): Task 1 migra TODOS los call sites de `Arrow(...)` a `Arrow.straight(...)`, así que la suite
  no queda "rota a medias".
- Entre Task 1 y Task 5, la animación de salida sigue siendo la traslación rígida vieja (el
  `ExitingArrowWidget` antiguo compila porque usa los getters de compat `direction`/`cells`). Es un
  interino esperado; Task 5 la sustituye por la serpiente.
- Tras Task 4 ya se ven flechas dobladas en tablero vertical denso. Tras Task 5, salida serpiente.

## Manejo de desviaciones

- Si un test no falla/pasa como dice el plan, **detente y diagnostica** (`systematic-debugging`); no
  parchees a ciegas.
- Si el código real difiere de lo que el plan asume, repórtalo al usuario antes de improvisar.
- **Tuning:** la densidad real la decide solo `LevelBlueprint.forLevel`. Si los tableros salen muy
  vacíos (degradación del generador) o muy llenos, ajusta esa única función (factor `0.68`,
  `maxPathLen`, clamps). No toques generador ni UI por tuning.
- **Animación:** si el slither se ve raro, los knobs están en `SnakeExitPainter` (duración 360 ms en
  `ExitingArrowWidget`, `beyond`, `shift`). No cambia la lógica de dominio.

## Estado al momento del handoff

- Spec, plan y este handoff **escritos y commiteados** (commits `f476729`, `e2a775e`, `09f5d97`, +
  el de este handoff). Rama `feat/main-sprint`.
- **WIP sin commitear:** `arrow_board.dart` + `graph_board_generator.dart` (overlaps — DEPENDENCIA del
  plan, commitéalos en el pre-flight) y `home_screen.dart` (no relacionado — déjalo aparte).
- Código de producción del sprint: **sin empezar**. Punto de arranque: **Task 1** del plan.

---

## Prompt para el agente ORQUESTADOR (cópialo tal cual)

```
Eres el ORQUESTADOR de un sprint de implementación en el proyecto ArrowMaze (cliente Flutter
en MazePruebaFront/). Tu rol: Arquitecto de Software Senior que coordina subagentes; no escribes
tú el código de producción ni los tests, los delegas y revisas.

USA la skill superpowers:subagent-driven-development para ejecutar, tarea por tarea, este plan:
  MazePruebaFront/docs/superpowers/plans/2026-06-20-flechas-dobladas-tablero-vertical.md

Antes de nada, lee en este orden:
  1) MazePruebaFront/docs/superpowers/specs/2026-06-20-flechas-dobladas-tablero-vertical-design.md
  2) MazePruebaFront/docs/superpowers/plans/2026-06-20-flechas-dobladas-tablero-vertical.md
  3) MazePruebaFront/docs/superpowers/plans/2026-06-20-flechas-dobladas-tablero-vertical-HANDOFF.md
El HANDOFF manda sobre entorno, pre-flight y reglas de commit; síguelo al pie.

Entorno: repo git en MazePruebaFront/ (rama feat/main-sprint); package flutter_arrow_maze;
PowerShell en Windows (haz `cd MazePruebaFront` al abrir shell). Respeta la arquitectura Clean
Mobile: domain/ es Dart puro; presentation/ solo consume application/.

PRE-FLIGHT OBLIGATORIO (antes de la Task 1):
  - El plan depende de ArrowBoard.overlaps, que está SIN commitear. Commitea como fragmento propio
    arrow_board.dart + graph_board_generator.dart (mensaje:
    "feat(front/domain): prevent overlapping arrows on placement"). Deja home_screen.dart fuera.
  - flutter pub get && flutter analyze && flutter test  → deben quedar verdes.

POR CADA TAREA (1 → 6, en orden):
  1) Despacha un subagente de IMPLEMENTACIÓN con los steps de CÓDIGO DE PRODUCCIÓN de la tarea
     (código exacto del plan, paths exactos).
  2) Despacha un subagente arrowmaze-qa (o qa-engineer) con el prompt "Delegar tests" de esa tarea,
     VERBATIM, para que escriba/migre las pruebas (AAA, mockeando externos).
  3) En Task 3, ejecuta `dart run build_runner build --delete-conflicting-outputs` (regenera mocks)
     antes de correr los tests.
  4) Corre `flutter test` y `flutter analyze`: exige VERDE antes de seguir.
  5) Aplica la revisión de dos etapas del skill; si algo no cuadra, NO parchees a ciegas: usa
     superpowers:systematic-debugging.
  6) Commit de la tarea (un commit por fragmento, Conventional Commits + entrada en AI_HISTORY.MD +
     trailer "Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"). Marca sus checkbox en el plan.
  7) CHECKPOINT con el usuario: resumen breve + resultado de flutter test. Espera OK para la siguiente.

Restricción del usuario (override sobre TDD inline): las pruebas las escribe SIEMPRE el subagente
arrowmaze-qa a partir del prompt de delegación del plan; nunca pegues tú código de test en el plan.

Si el código real difiere de lo que el plan asume, repórtalo antes de improvisar. Empieza por el
PRE-FLIGHT y luego la Task 1.
```
