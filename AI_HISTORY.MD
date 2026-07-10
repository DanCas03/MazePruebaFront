# AI History — MazePruebaFront

## Entrada 041 — front#1 (fragmento 3): batch v1 de 30 candidatos congelado

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Fragmento 3 (final) del issue front#1. Ejecutar el script y congelar en git el batch v1: 30 JSON de candidatos + `manifest.md` en `tool/candidates/`. Estos archivos son el artefacto congelado real que consume la curación (E2.2) y desbloquea back#10 (seed Prisma con 15 niveles).
**Herramienta de IA utilizada:** Claude Code (Opus 4.8).
**Prompt o instrucción proporcionada:** > "Ejecuta el plan del issue 1 del front (script generador de candidatos)."
**Resultado obtenido:**
- `tool/candidates/cand-t{1..5}-s*.json` (30 nuevos) + `tool/candidates/manifest.md`: 6 candidatos por tier, dims 6x8 → 11x15, **0 degradados** (todos colocan las flechas pedidas).
- AC de reproducibilidad verificado: re-ejecutar el script no cambia ningún byte (`git diff` vacío tras el `git add`; archivos LF estables, sin conversión CRLF). Formato wire y variedad de dims cubiertos por los tests del fragmento 1 y el manifiesto.
**Modificaciones realizadas por el equipo:**


## Entrada 040 — front#1 (fragmento 2): script generador de candidatos + docs

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Fragmento 2 del issue front#1. CLI `tool/generate_level_candidates.dart` que corre `GraphBoardGenerator` con una tabla FIJA de 30 seeds (5 tiers × 6, 2x oversupply) y escribe un JSON wire-estricto por candidato + `manifest.md` en `tool/candidates/` (default, `--out` opcional). La reproducibilidad vive en la tabla versionada; el artefacto congelado real son los JSON commiteados (`Random(seed)` de Dart no es estable entre SDKs). Degradación con gracia: si el generador coloca menos flechas de las pedidas, se exporta igual y el manifiesto lo marca `(!)`.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8); test de determinismo delegado a subagente QA.
**Prompt o instrucción proporcionada:** > "Ejecuta el plan del issue 1 del front (script generador de candidatos)."
**Resultado obtenido:**
- `tool/generate_level_candidates.dart` (nuevo): CLI fino (`dart:io`, sin arrancar Flutter) con `CandidateSpec` + `_batchSpec` (rampa 6x8→11x15, maxPathLen 4→7) y armado del manifiesto.
- `test/infrastructure/serialization/level_generation_determinism_test.dart` (nuevo): 2 tests AAA sobre generador+encoder (misma seed → mismo JSON; seeds distintas → JSON distinto). Verde.
- `README.md`: sección Tooling con el uso del script. `CONTEXT.md`: glosario "Producción de niveles" (Candidato / Curación / Tier).
- Smoke run: 30 candidatos, 0 degradados. `flutter analyze` limpio; suite completa 217/217 verde.
**Modificaciones realizadas por el equipo:**


## Entrada 039 — front#1 (fragmento 1): LevelJsonEncoder (formato wire arrow-path)

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Fragmento 1 del issue front#1 (= E2.1 del backlog de cutover). Serializar un `ArrowBoard` al JSON arrow-path wire-estricto del contrato canónico (`CONTEXT-MAP.md` raíz): `{levelId, cols, rows, timeLimitSec?, arrows:[{id, headDir, cells:[[row,col],…]}]}`, con `cells` de cola→cabeza y sin claves extra (copiable tal cual al seed del back). El encoder es el inverso natural del futuro `LevelDto.fromJson` (E1.3/front#8) sin adelantarlo.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) — rama `chore/front1-level-candidates`; tests delegados a subagente QA.
**Prompt o instrucción proporcionada:** > "Ejecuta el plan del issue 1 del front (script generador de candidatos)."
**Resultado obtenido:**
- `lib/infrastructure/serialization/level_json_encoder.dart` (nuevo): `LevelJsonEncoder` con `toMap(...)` y `encode(...)`. `encode` usa `JsonEncoder.withIndent('  ')` + newline final para salida byte-estable (congelable en git). Solo importa `domain/` (capa correcta).
- `test/infrastructure/serialization/level_json_encoder_test.dart` (nuevo): 7 tests AAA `should_..._when_...` sin mocks (claves exactas del wire, cells cola→cabeza en flecha doblada, 4 direcciones, omitir/incluir timeLimitSec, arrows vacío, indent+newline). 7/7 en verde; `flutter analyze` sin issues nuevos.
**Modificaciones realizadas por el equipo:**

## Entrada 038 — front#11: límite de tiempo opcional con reloj inyectable

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Issue front#11 (plan E4.5/E4.6, ADR 0001 decisión 6) — dar a los niveles avanzados un `timeLimitSec` opcional y una cuenta atrás que, al agotarse, transiciona a `GameLost`. El reloj debe ser **inyectable** para poder probar el timeout con un reloj falso, sin fragilidad temporal. Depende de front#2 (`GameLost`, ya en `origin/main`) y de back#5 (que el JSON de `Level` traiga `timeLimitSec`); como el front aún genera niveles en local (no consume el back), el portador del límite en el front es `LevelBlueprint`.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) — rama `feat/#11-time-limit-clock` desde `origin/main` (no desde `main` local, contaminado por `ci/#7` sin mergear), guiado por Claudia. Convención de modelos del equipo: dominio→Fable, aplicación/cableado→Sonnet, pantallas→Opus; aquí implementado end-to-end por Opus.
**Prompt o instrucción proporcionada:** > "Sigamos con el issue front#11" (con la indicación de dividir en commits no muy cargados y pedir autorización antes del PR).
**Resultado obtenido (3 commits):**
- **Commit 1 (domain):** `lib/domain/game_core/services/i_ticker.dart` (nuevo) — puerto `ITicker` que emite los segundos restantes hasta 0, con `NullTicker` (Null Object) como valor por defecto inerte para no acoplar la aplicación a infraestructura. `LevelBlueprint` gana `timeLimitSec` opcional; la curva asigna límite desde el nivel 6 (90 s bajando 5 s/nivel, piso 30 s). Tests AAA que fijan la curva (sin límite bajo el umbral, 90 s de arranque, decremento, piso e invariante de rango).
- **Commit 2 (application/infra):** `GameController` recibe un `ITicker` opcional; `loadLevel` arranca la cuenta atrás si el blueprint tiene límite, cada tick refresca `GamePlaying.remainingSeconds` y el 0 emite `GameLost`; la suscripción se cancela en victoria/derrota/recarga y en `dispose` (sin fugas de reloj). `GamePlaying` expone `remainingSeconds` (null si el nivel no está cronometrado). `SystemTicker` (nuevo, infra) implementa `ITicker` sobre `Stream.periodic`. `main.dart` inyecta `SystemTicker` en el override del `GameController` — **esto además restaura el override de `gameControllerProvider` que se había perdido al cablear auth (regresión de BUG-2: entrar a la partida lanzaba `UnimplementedError`)**. Tests AAA con reloj falso controlado a mano: la cuenta atrás solo arranca en niveles con límite, los segundos se actualizan por tick, el timeout pierde, y un tick tardío tras la victoria se ignora.
- **Commit 3 (presentation):** `game_screen.dart` muestra en la AppBar un `_CountdownChip` (`m:ss`, icono `timer_outlined`) cuando `remainingSeconds != null`. Tests de widget: se ve "1:30" en un nivel cronometrado y no hay reloj en uno sin límite.
- **Verificación:** `flutter analyze` sobre lo tocado → "No issues found!"; suite completa **220/220 verde**.
- Nota de numeración: en `origin/main` el tope es 034; 035/036 viven en `ci/#7` y 037 en `feat/#10` (ambas aún sin mergear). Se usa 038 para no colisionar.
## Entrada 037 — front#10: pantalla de derrota con reintento

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Issue front#10 — al entrar en `GameLost` (5º choque, front#2) mostrar una pantalla de derrota con un CTA "Retry" que recarga el mismo nivel. Requería que la navegación por ruta nombrada propagara los `arguments` (el `_fade` del router los descartaba), porque el reintento necesita el `LevelId` de la partida perdida.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) — rama `feat/#10-defeat-screen` desde `origin/main`, guiado por Claudia.
**Prompt o instrucción proporcionada:** > "Sigamos con el issue front#10"
**Resultado obtenido:**
- `lib/presentation/level_selection/defeat_screen.dart` (nuevo): `DefeatScreen` espejo de `VictoryScreen` (icono `error`, "Out of Moves!", resumen `N moves · M strikes`). CTA primario "Retry" hace `pushReplacementNamed(AppRouter.game, arguments: levelId)` → monta un `GameScreen` nuevo que recarga el nivel en `initState` (generación determinista ⇒ mismo tablero). CTA secundario "Back to Levels" limpia la pila. Args de ruta tipados con el record `DefeatArgs = ({LevelId levelId, int moves, int strikes})`; si faltan, "Retry" queda deshabilitado.
- `lib/core/router/app_router.dart`: ruta `/defeat` registrada; `_fade` ahora **reenvía `RouteSettings`** a la ruta (antes los omitía, así que `ModalRoute...arguments` llegaba nulo en producción). Efecto colateral positivo: `VictoryScreen` ahora muestra los movimientos reales en la app, no solo en tests.
- `lib/presentation/game/screens/game_screen.dart`: el `ref.listen` que ya navegaba a victoria en `GameWon` ahora también navega a `/defeat` en `GameLost`, pasando `levelId`, `moves` y `strikes`.
- Tests AAA: `game_screen_test.dart` — `navigates to DefeatScreen when the fifth collision is reached` (transición requerida por el issue, con un generador de flecha bloqueada); `defeat_screen_test.dart` (nuevo) — render de args, fallback con "Retry" deshabilitado, "Retry" reenvía el `LevelId`, "Back to Levels" vuelve al selector.
- Verificación: `flutter analyze` sobre lo tocado → "No issues found!"; suite completa **213/213 verde**.
- Nota de numeración: en `main` la última entrada es 034; 035 (fix home) y 036 (front#7 CI) viven en `ci/#7-flutter-checks` aún sin mergear. Se reserva 037 para no colisionar cuando esa rama entre.

## Entrada 036 — front#7: CI de GitHub Actions (analyze + test en PR) + badge

**Fecha:** 2026-07-08
**Tarea o problema abordado:** Issue front#7 — workflow de GitHub Actions que corre `flutter analyze` + `flutter test` en cada PR y en push a `main`; badge real de build en el README (reemplaza los badges estáticos de tests/analyze que decían "105 passing" y ya estaban desactualizados). La protección de `main` (PR obligatorio + checks + 1 review) es configuración del repo en GitHub Settings y se hace aparte (requiere admin).
**Herramienta de IA utilizada:** Claude Code (Fable 5) — rama `ci/#7-flutter-checks`, guiado por Claudia.
**Prompt o instrucción proporcionada:** > "sí, sigamos con eso" (front#7 tras dejar la suite verde)
**Resultado obtenido:**
- `.github/workflows/ci.yml` (nuevo): job único `flutter analyze + test` en ubuntu-latest con `subosito/flutter-action@v2` (canal stable, cache activado), disparado por `pull_request` y `push` a `main`.
- `README.md`: badge dinámico de CI apuntando al workflow; nota actualizada (antes decía "CI is not wired up yet").
- Dependencia de orden: mergear ANTES `fix/home-screen-tests` (Entrada 035) o el primer run del CI saldrá rojo por los tests desincronizados del home.
- Nota de numeración: asume 033 = front#2, 034 = front#3, 035 = fix home tests (ramas paralelas).
## Entrada 034 — front#3: test de regresión BUG-1 (undo tras victoria preserva el contador)

**Fecha:** 2026-07-08
**Tarea o problema abordado:** Issue front#3 — BUG-1: al deshacer inmediatamente tras `GameWon` el contador se reiniciaba a 0 en vez de `moves - 1` (`docs/superpowers/progress/OPEN-ITEMS.md`). Al investigar se comprobó que **el fix ya vive en `main`**: la reescritura de `undoMove()` de la Task 4.2 (Entrada 028) toma `current.moves.value` también en la rama `GameWon`. Lo que faltaba era el test de regresión que el propio OPEN-ITEMS señala como hueco ("ningún test lo cubre hoy").
**Herramienta de IA utilizada:** Claude Code (Fable 5) — rama `fix/#3-undo-victory-move-count`, guiado por Claudia.
**Prompt o instrucción proporcionada:** > "sí, sigamos con front#3"
**Resultado obtenido:**
- `test/application/state/game_controller_test.dart`: nuevo test AAA `should_preserve_move_count_when_undo_after_victory` — 2 taps legales vacían el tablero (`GameWon`, moves == 2), `undoMove()` deja `GamePlaying` con `moves == 1` y la flecha reinsertada.
- **Verificación por mutación:** reintroduciendo el bug temporalmente (`currentMoves = 0` en la rama `GameWon`) el test falla; con el código real pasa. Cumple el criterio "test que falla antes del fix y pasa después".
- `flutter analyze` → "No issues found!"; suite 181/183 (los 2 fallos de `home_screen_test.dart` preexisten en `main` y están reportados aparte).
- Nota de numeración: asume que la Entrada 033 (front#2, rama paralela) mergea primero.
## Entrada 033 — front#2: GameLost + contador de choques (5)

**Fecha:** 2026-07-08
**Tarea o problema abordado:** Issue front#2 — añadir `GameLost` al `GameState` sellado y un contador de choques: tocar una flecha bloqueada suma 1; al 5º choque la partida se pierde (ADR 0001, decisión 6). Se reutilizan `blockedArrow`/`blockedNonce` para el feedback de shake en los choques no fatales.
**Herramienta de IA utilizada:** Claude Code (Fable 5) — implementación guiada por Claudia sobre la rama `feat/#2-gamelost-strikes`.
**Prompt o instrucción proporcionada:** > "sí, arranquemos con front#2"
**Resultado obtenido:**
- `lib/domain/game_core/value_objects/strike_count.dart` (nuevo): VO `StrikeCount` estilo `MoveCount` con `max = 5`, `increment()` e `isFatal` — la regla de derrota vive en dominio.
- `lib/application/state/game_state.dart`: `GameLost {moves, strikes}` añadido al sealed class; `GamePlaying` expone `strikes` (default 0) para que la UI pueda mostrar el contador (front#10/#11).
- `lib/application/state/game_controller.dart`: `_strikes` con alcance de partida (como `_blockedNonce`), reset en `loadLevel`; en el branch de choque incrementa y al ser fatal emite `GameLost` (sin shake); los estados `GamePlaying` propagan `strikes`.
- Tests AAA en `game_controller_test.dart`: `should_lose_when_fifth_collision` (requerido por el issue), `should_keep_playing_when_fourth_collision` y `should_reset_strikes_when_level_reloaded`.
- Verificación: `flutter analyze` → "No issues found!"; suite 181/183 — los 2 fallos son de `home_screen_test.dart` y **preexisten en `main` limpio** (verificado con stash), no los introduce este cambio.
## Entrada 035 — Fix: tests de HomeScreen desincronizados del rediseño (main en rojo)

**Fecha:** 2026-07-08
**Tarea o problema abordado:** Los 2 tests de `home_screen_test.dart` fallaban en `main` limpio (detectado al verificar front#2). Causa raíz doble: (1) los tests buscaban los textos del home original en inglés ('Arrow Maze', 'Clear the board', botón 'Play') pero el rediseño mergeado renderiza 'ARROW MAZE', 'Despeja el tablero. Saca cada flecha.' y 'JUGAR'; (2) el test de navegación usaba `pumpAndSettle()`, que nunca se asienta porque el logo `_LogoArrows` anima en bucle infinito (`AnimationController..repeat()`). Bloqueaba front#7: el CI correría `flutter test` en rojo para todos los PRs.
**Herramienta de IA utilizada:** Claude Code (Fable 5) — rama `fix/home-screen-tests`, guiado por Claudia.
**Prompt o instrucción proporcionada:** > "sí, sigamos con eso" (arreglar los tests preexistentes antes de montar el CI de front#7)
**Resultado obtenido:**
- `test/presentation/home/home_screen_test.dart`: asserts actualizados a los textos reales del widget (fuente de verdad); el tap navega con pumps acotados (`pump()` + `pump(400ms)`) en vez de `pumpAndSettle()`.
- Suite completa **182/182 verde por primera vez** en esta máquina; `flutter analyze` → "No issues found!".
- Nota: cuando front#4 (i18n, Isaac) extraiga los strings, estos asserts deberán pasar a keys localizadas.
- Nota de numeración: asume 033 = front#2 y 034 = front#3 (ramas paralelas).
**Modificaciones realizadas por el equipo:**

## Entrada 032 — Fix colateral: stubs de ILevelGenerator + lints (cierre Fase 5)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Al restaurar la Fase 5 la compilación de toda la UI (rota desde la Fase 1), afloraron 2 errores de compilación colaterales del cambio de firma de la Fase 3 (`ILevelGenerator.generate` ganó `int? seed`): los stubs `_SingleArrowGenerator` (game_screen_test) y `_EmptyBoardGenerator` (level_selection_screen_test) ya no eran overrides válidos. Más 2 lints menores. Estos archivos de test son objetivos de la Fase 6; el fix aquí es mínimo y conserva el comportamiento para dejar `flutter analyze` limpio y la suite completa verde al cierre de la Fase 5.
**Herramienta de IA utilizada:** Claude Code — corrección mecánica del orquestador (Opus 4.8), no implica lógica de negocio.
**Prompt o instrucción proporcionada:** > "(verificación de cierre de Fase 5: flutter analyze debe quedar limpio)"
**Resultado obtenido:**
- `test/presentation/game/screens/game_screen_test.dart` y `test/presentation/level_selection/level_selection_screen_test.dart`: añadido `int? seed` a la firma de `generate` de los stubs (override válido, comportamiento intacto).
- `test/domain/entities/arrow_board_test.dart`: renombrado `_board2` → `board2` (lint no_leading_underscores_for_local_identifiers).
- `test/presentation/game/painters/arrow_painter_test.dart`: quitado import innecesario de `material.dart` (ya commiteado con Task 5.1).
- Resultado: `flutter analyze` → "No issues found!"; `flutter test` → 133/133 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 031 — Task 5.3: BoardWidget responsive + hit-testing por celda (fix bug 1)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Bug visual 1 (no se sabe qué flecha se toca): reemplazar el `Stack` de `ArrowWidget` con `GestureDetector` por flecha (bounding boxes solapados) por un layout responsive con hit-testing por celda a nivel de tablero. Resuelve definitivamente "qué flecha toco" y es agnóstico de forma.
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (fase VISUAL: impl + revisión Opus 4.8; testing Sonnet 4.6).
**Prompt o instrucción proporcionada:** > "Fase 5 — Render del tablero (arregla los 2 bugs visuales)."
**Resultado obtenido:**
- `lib/presentation/game/widgets/board_widget.dart`: `ConsumerWidget` con `LayoutBuilder` (cell = min(maxW/cols, maxH/rows)), rejilla sutil de fondo (`_GridPainter`), una flecha por `Positioned` (bbox), UN solo `GestureDetector` (`HitTestBehavior.opaque`) con `onTapUp` → `col/row` por floor+clamp → `ArrowBoard.arrowAt(Position)` → `controller.tapArrow(id)`. Overlay de salida cuando `state.exitingArrow != null` (keyed por exitNonce). `clipBehavior: Clip.none`; `SizedBox.shrink()` si no es `GamePlaying`.
- Test migrado in-place `board_widget_test.dart` con `@GenerateMocks([ILevelGenerator, RemoveArrowUseCase])` + `board_widget_test.mocks.dart`: regresión del bug (toque en huella de arrow-2 → `tapArrow(arrow-2)`; celda vacía → ningún execute) + "renders nothing while not playing".
- Revisión Opus `arrowmaze-code-reviewer`: ✅ ambos bugs resueltos de forma robusta; arquitectura/SOLID/AOP limpios. Fase 5 cerrada: 133/133 verde, `flutter analyze` limpio.
**Modificaciones realizadas por el equipo:**

## Entrada 030 — Task 5.2: ArrowWidget render-only (shake) + ExitingArrowWidget (slide-out)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Separar render de gesto: `ArrowWidget` pasa a render puro (sin `GestureDetector`, `IgnorePointer`) con shake al cambiar `blockedNonce`; `ExitingArrowWidget` reescrito como overlay auto-desmontable keyed por `nonce` (slide en dirección de la punta + fade) usando el nuevo painter. Se elimina código muerto (`isHighlighted`, `onTap`, `onComplete`, `cellSize`).
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (fase VISUAL: impl + revisión Opus 4.8; testing Sonnet 4.6).
**Prompt o instrucción proporcionada:** > "las fases visuales (5 render y 6 pantallas) usarán Opus para implementación y revisión."
**Resultado obtenido:**
- `lib/presentation/game/widgets/arrow_widget.dart`: `StatefulWidget` render-only, recibe `cells`/`color`/`isBlocked`/`blockedNonce` (vía minCol/minRow/cell), shake con onda amortiguada en `didUpdateWidget`. Sin gesto (el tablero hace hit-testing).
- `lib/presentation/game/widgets/exiting_arrow_widget.dart`: overlay keyed por `nonce`, anima slide (dirección de la punta) + fade y luego `SizedBox.shrink()`. Sin métodos de "limpiar estado" ni emisiones extra (§7.4).
- Tests migrados in-place `arrow_widget_test.dart` (render + disparo de shake) y `exiting_arrow_widget_test.dart` (mount, mid-anim, dispose sin leak, keying por nonce).
- Revisión Opus: ✅. Suite completa verde, analyze limpio.
**Modificaciones realizadas por el equipo:**

## Entrada 029 — Task 5.1: ArrowPainter por polilínea (cuerpo grueso + glow + punta)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Bug visual 2 (flechas sin cuerpo): reescribir `ArrowPainter` para dibujar la flecha como polilínea desde `arrow.cells` en coordenadas locales (origen `minCol`/`minRow`), agnóstica de la forma (habilita flechas dobladas), con cuerpo grueso + glow + brillo interior + punta triangular orientada por el último segmento.
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE. Por ser fase VISUAL, implementación y revisión en **Opus 4.8** (a pedido del usuario, para garantizar fidelidad al aspecto de referencia); testing en Sonnet 4.6.
**Prompt o instrucción proporcionada:** > "Me interesa que los agentes que directamente tengan que ver con el diseño de cómo se ve sean opus. Para que no haya fallo de que el juego se va a ver al menos parecido a la versión pasada."
**Resultado obtenido:**
- `lib/presentation/game/painters/arrow_painter.dart`: firma `ArrowPainter({required List<Position> cells, required Color color, required double cell, required int minCol, required int minRow})`. 4 capas (spec §6.1): glow `color@0.30`+`MaskFilter.blur`, cuerpo `cell*0.40`, brillo interior `white@0.22`, punta triangular vía `atan2` del segmento `cells[n-2]→cells[n-1]`. `StrokeJoin/Cap.round`.
- Test migrado in-place `test/presentation/game/painters/arrow_painter_test.dart` (smoke de paint sin throw recta/1-celda + shouldRepaint; quitado import innecesario).
- Revisión Opus `arrowmaze-code-reviewer`: ✅ "reproducirá fielmente el aspecto de referencia". Minor: orientación de punta con 1 celda (mitigado por length>=2 del generador). Fase 5: suite completa 133/133 verde, `flutter analyze` limpio.
**Modificaciones realizadas por el equipo:**

## Entrada 028 — Task 4.2: GamePlaying extendido + GameController reescrito (blueprint, feedback, restart)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Extender `GamePlaying` con señales transitorias de presentación (`blockedArrow`, `blockedNonce`, `exitingArrow`, `exitNonce`, `canUndo`) y reescribir `GameController` para escalar tableros por nivel via `LevelBlueprint`, dar feedback de bloqueo/salida, soportar `restartLevel()`, y corregir el bug de undo desde `GameWon` con dimensiones 4×4 hardcodeadas.
**Herramienta de IA utilizada:** Antigravity IDE (Claude Opus 4.6 Thinking) — ejecución inline por fases con checkpoints.
**Prompt o instrucción proporcionada:** > "Fase 4 — Estado de aplicación: Task 4.2 GamePlaying+GameController."
**Resultado obtenido:**
- `lib/application/state/game_state.dart`: `GamePlaying` con 5 campos transitorios nuevos (señales de presentación, no reglas de dominio).
- `lib/application/state/game_controller.dart`: `loadLevel` usa `LevelBlueprint.forLevel(levelId.number)` + `seed: levelId.number`; `tapArrow` con feedback de bloqueo/salida; `undoMove` con dimensiones reales del nivel; `restartLevel()` nuevo.
- Test migrado `test/application/state/game_controller_test.dart` con `@GenerateMocks([ILevelGenerator, RemoveArrowUseCase])`: 7 tests (loadLevel, blueprint+seed verify, blocked shake, legal exit, victory, undo, restart). 7/7 GREEN.
**Modificaciones realizadas por el equipo:**


## Entrada 027 — Task 4.1: CommandInvoker.clear() para restart de nivel

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Añadir `clear()` al `CommandInvoker` para vaciar el historial de undo al reiniciar un nivel, evitando que el jugador deshaga movimientos de una partida anterior.
**Herramienta de IA utilizada:** Antigravity IDE (Claude Opus 4.6 Thinking) — ejecución inline por fases con checkpoints.
**Prompt o instrucción proporcionada:** > "Fase 4 — Estado de aplicación: Task 4.1 CommandInvoker.clear()."
**Resultado obtenido:**
- `lib/application/commands/command_invoker.dart`: `void clear() => _history.clear();` — una línea que delega en el `List.clear` interno.
- Test preexistente en `test/application/commands/command_invoker_test.dart` (escrito en TDD-first por subagente previo, confirmado RED). Ahora GREEN (5/5).
**Modificaciones realizadas por el equipo:**


## Entrada 026 — Task 3.1: Generación determinista y escalable por nivel

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Hacer el generador determinista por nivel (mismo `seed` ⇒ mismo tablero, para que "reintentar" reproduzca el puzzle), robusto en tableros grandes y con flechas siempre de longitud ≥ 2. El puerto `ILevelGenerator` expone ahora `seed`; el `GraphBoardGenerator` escala `maxAttempts` y degrada con gracia si no caben todas las flechas.
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (testing + implementación Sonnet 4.6; orquestación/revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "Fase 3 — Generación escalada por nivel: generador determinista por seed, longitud mín. 2, maxAttempts escalado, degradación logueada."
**Resultado obtenido:**
- `lib/domain/arrows/services/i_level_generator.dart`: puerto → `generate({required cols, rows, arrowCount, int? seed})`. Dominio puro (solo importa `arrow_board.dart`).
- `lib/infrastructure/generators/graph_board_generator.dart`: `Random(seed)` como único origen de aleatoriedad (determinismo verificado); longitud en `2..maxLen` (guard `maxLen<2` evita flechas de 1 celda); `maxAttempts = cols*rows*30`; degradación con gracia (coloca las que caben, sin lanzar); invariante DAG/resolubilidad preservado en cada inserción (`tempBoard.canExit`). Constructor argless-compatible `GraphBoardGenerator({ILoggerService? logger})` → `main.dart` y `dependency_providers` siguen compilando sin cambios.
- Tests migrados in-place: `graph_board_generator_test.dart` (determinismo, dims/count, longitud≥2, solvabilidad, escalado, seeds distintos, degradación) y `i_level_generator_test.dart` (contrato LSP con seed opcional). 14/14 verde.
- Revisión `arrowmaze-code-reviewer`: ✅ sin blockers. Desviación consciente: el plan difirió el logger AOP ("excede esta tarea"); la impl lo añadió como inyección OPCIONAL (aditiva, DIP) para honrar spec §8.3. Pendiente de decisión: cablearlo en el composition root (hoy no-op en prod). WARNINGs de test (degradación trivialmente verde, determinismo duplicado) → revisión final.
**Modificaciones realizadas por el equipo:**

## Entrada 025 — Task 2.3: LevelBlueprint (curva de dificultad, dominio)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Encapsular TODA la curva de dificultad (tamaño del tablero y número de flechas por nivel) en un único VO de dominio testeable (`LevelBlueprint.forLevel`), separando la *política de dificultad* de la *generación* (D7/SRP/OCP). Elimina conceptualmente el `4×4×5` fijo de `loadLevel` (que se cablea en la Fase 4).
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (testing + implementación Sonnet 4.6; orquestación/revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "Fase 2 — Dominio: queries y dificultad… (Task 2.3 LevelBlueprint)."
**Resultado obtenido:**
- `lib/domain/board/value_objects/level_blueprint.dart` (NUEVO): `factory LevelBlueprint.forLevel(int level)` con `size = (4 + (level-1) ~/ 2).clamp(4, 9)` y `arrowCount = ((size*size*0.5)/3).round().clamp(4, size*size)`. Dart puro (sin Flutter ni infra). Determinista, monótona no-decreciente; size llega a 9 en nivel 11.
- Test nuevo `test/domain/board/value_objects/level_blueprint_test.dart` (mínimo en nivel 1, tope 9, monotonía iterando 1–30, clamp en niveles fuera de rango).
- Fase 2 cerrada: 17/17 verde; revisión `arrowmaze-code-reviewer` ✅ (fórmula idéntica a spec §8.1, verificada numéricamente). Minors anotados (Equatable, comentario, anclaje de boundary) → revisión final.
**Modificaciones realizadas por el equipo:**

## Entrada 024 — Task 2.2: LevelId.number (parseo con fallback)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Centralizar el parseo del nivel numérico en el VO `LevelId` sin cambiar su tipo `String` ni romper rutas/selector. Lo usan la curva de dificultad (`LevelBlueprint`), el seed determinista del generador y el "siguiente nivel" de la pantalla de victoria.
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (testing + implementación Sonnet 4.6; orquestación/revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "Fase 2 — Dominio: queries y dificultad… (Task 2.2 LevelId.number)."
**Resultado obtenido:**
- `lib/domain/board/value_objects/level_id.dart`: `int get number => int.tryParse(value) ?? 1;`. No muta `value`, no afecta `props`/igualdad de Equatable.
- Test nuevo en ruta anidada `test/domain/board/value_objects/level_id_test.dart` (parseo numérico + fallback 1 para no numéricos).
- Fase en verde. Revisión `arrowmaze-code-reviewer`: ✅ (dominio puro). Minor anotado: el archivo no cubre el guard del constructor — diferido a la revisión final.
**Modificaciones realizadas por el equipo:**

## Entrada 023 — Task 2.1: ArrowBoard — queries puras arrowAt / arrowById

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Añadir al aggregate root `ArrowBoard` dos queries puras de solo lectura: `arrowAt(Position) → Arrow?` (para el hit-testing por celda de la Fase 5) y `arrowById(ArrowId) → Arrow?` (para el "fantasma" de salida del controller), sin exponer la lista interna de flechas fuera del aggregate.
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (testing + implementación Sonnet 4.6; orquestación/revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "Fase 2 — Dominio: queries y dificultad… a) TESTING confirma ROJO; b) IMPLEMENTACIÓN deja VERDE."
**Resultado obtenido:**
- `lib/domain/arrows/entities/arrow_board.dart`: `arrowById` delega en `_findById`; `arrowAt` itera `a.cells.contains(pos)` (agnóstico de dirección y longitud, soporta flechas multi-celda y dobladas futuras). Solo lectura, Dart puro.
- Tests migrados in-place en `test/domain/entities/arrow_board_test.dart`: +4 tests (arrowAt/arrowById presente y null) conservando los 7 preexistentes.
- Fase 2 en verde (17/17). Revisión `arrowmaze-code-reviewer`: ✅ dominio puro; queries de solo lectura correctas.
**Modificaciones realizadas por el equipo:**

## Entrada 022 — Task 1.3: Helper de color por flecha (presentación)

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Derivar un color estable por flecha desde `ArrowId` EN LA CAPA DE PRESENTACIÓN (spec D3), manteniendo el dominio puro (sin `colorIndex` en entidades).
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (testing + implementación Sonnet 4.6; orquestación/revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "package = flutter_arrow_maze… a) Despacha el subagente de TESTING → crea todos los tests de la fase y confírmalos en ROJO."
**Resultado obtenido:**
- `lib/presentation/game/arrow_color.dart` (NUEVO): `arrowColorIndex(ArrowId)` parsea el sufijo numérico de ids `arrow-N` (fallback determinista vía `hashCode`) y `arrowColorFor(ArrowId)` resuelve `AppColors.arrowColor(arrowColorIndex(id))`. Índice estable por identidad (no por posición), así el color no salta al remover flechas.
- Tests en `test/presentation/game/arrow_color_test.dart` (parseo, wrap-around, estabilidad, fallback); commiteado junto a su código.
- Fase 1 cerrada: 11/11 verde; revisión `arrowmaze-code-reviewer` ✅ (capas limpias: presentación importa solo `ArrowId` + `AppColors`, sin fuga al dominio). Minor S2 pendiente (test de estabilidad del fallback no-numérico) anotado para la revisión final.
**Modificaciones realizadas por el equipo:**

## Entrada 021 — Task 1.2: AppTheme alimentado por la paleta jewel

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Realimentar los `ColorScheme` claro/oscuro de `AppTheme` desde la nueva paleta jewel, conservando la estructura (dos `ThemeData`, `ThemeMode.system` en `main.dart`).
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (testing + implementación Sonnet 4.6; orquestación/revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "Por cada fase… b) Despacha el subagente de IMPLEMENTACIÓN → escribe el código de producción hasta dejar la fase en VERDE."
**Resultado obtenido:**
- `lib/core/theme/app_theme.dart`: `dark()` y `light()` construyen el `ColorScheme` desde la paleta jewel (primary/secondary/surface/onSurface/error), `scaffoldBackgroundColor` desde `background`/`lightBackground`, `useMaterial3: true`, `fontFamily: 'Roboto'`, `onPrimary: AppColors.onBackground`.
- Test migrado in-place a la ruta anidada existente `test/core/theme/app_theme_test.dart`: aserciones de paleta vieja reemplazadas por verificación del fondo y de `colorScheme.primary/secondary` por tema; conservada la cobertura de comportamiento previo (brightness, useMaterial3).
- Fase en verde. Revisión `arrowmaze-code-reviewer`: ✅.
**Modificaciones realizadas por el equipo:**

## Entrada 020 — Task 1.1: AppColors — paleta jewel dual + arrowColor

**Fecha:** 2026-06-19
**Tarea o problema abordado:** Reemplazar el modelo de color por dirección (`arrowUp/Down/Left/Right` + `arrowHighlight`) por una paleta "jewel" dual (oscuro/claro) con `arrowPalette` de 8 tonos y helper `arrowColor(int)` con wrap-around. Fundación del port visual del tablero (spec §5), antes de tocar el render.
**Herramienta de IA utilizada:** Claude Code — subagent-driven por FASE (subagente de testing + subagente de implementación, ambos Sonnet 4.6; orquestación + revisión Opus 4.8).
**Prompt o instrucción proporcionada:** > "Ejecuta el plan de Arrow Maze con la modalidad SUBAGENT-DRIVEN POR FASE: 2 subagentes por fase (1 de testing, 1 de implementación)… Empieza por la Fase 1."
**Resultado obtenido:**
- `lib/core/theme/app_colors.dart` reescrito: paleta oscura (background `#0E1020`, backgroundDeep `#070812`, surface `#181B30`, pill `#242843`, primary `#5B6CC4`, victory `#E0B45A`) + variantes claras + `arrowPalette` de 8 tonos + `arrowColor(int)` (wrap-around módulo 8). Eliminados `arrowUp/Down/Left/Right` y `arrowHighlight` (su único consumidor de producción, `arrow_painter.dart`, se reescribe en la Fase 5).
- Tests de la paleta (TDD-first) en `test/presentation/game/arrow_color_test.dart` (rango, wrap-around, tamaño 8); ese archivo se commitea con la Task 1.3 porque también cubre el helper de presentación.
- Fase 1 en verde (11/11). Revisión `arrowmaze-code-reviewer`: ✅ sin blockers; dominio puro intacto.
**Modificaciones realizadas por el equipo:**

## Entrada 019 — BUG-2 Fix: gameControllerProvider sin override + loadLevel nunca llamado

**Fecha:** 2026-06-18
**Tarea o problema abordado:** BUG-2 (Blocker) — la app crasheaba al entrar a la partida con `UnimplementedError: gameControllerProvider must be overridden with composed dependencies` (BUG A), y tras parchar ese crash el tablero quedaba en blanco porque nadie llamaba `loadLevel` al navegar (BUG B).
**Herramienta de IA utilizada:** Claude Code (Sonnet 4.6)
**Prompt o instruccion proporcionada:** > "Necesito que me ayudes a corregir el bug que se presenta en la aplicacion. Tienes Handoff de debug en arrowmaze-debug-handoff-2026-06-18.md […] utiliza las skills recomendadas en el handoff y ayudame a resolver el problema."
**Resultado obtenido:**
- **TDD RED primero:** Se agregó el test de regresión `BUG-2 regression: navigating to /game via router renders board without manual loadLevel call` en `test/presentation/game/screens/game_screen_test.dart`. Falló con `Error: No named parameter with the name 'levelId'`, confirmando que prueba el comportamiento faltante.
- **Fix A — `lib/main.dart`:** Se añadieron imports de `GameController`, `CommandInvoker`, `RemoveArrowUseCase` y `GraphBoardGenerator`. El `runApp` ahora pasa `overrides: [gameControllerProvider.overrideWith(() => GameController(GraphBoardGenerator(), RemoveArrowUseCase(), CommandInvoker()))]` al `ProviderScope`. El composition root es el único sitio que puede ver infraestructura (DIP).
- **Fix B — `lib/presentation/game/screens/game_screen.dart`:** `GameScreen` convirtido de `ConsumerWidget` a `ConsumerStatefulWidget` con campo `required LevelId levelId`. El `initState` del state usa `WidgetsBinding.instance.addPostFrameCallback` para llamar `ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId)` después del primer frame (garantiza que `ProviderScope` esté activo antes de mutar el notifier).
- **Fix C — `lib/core/router/app_router.dart`:** La ruta `/game` ahora lee `settings.arguments as LevelId` (fallback `LevelId('1')`) y pasa el id al `GameScreen(levelId: ...)`.
- **Fix D — `lib/presentation/level_selection/level_selection_screen.dart`:** El `onTap` de cada nivel ahora hace `Navigator.pushNamed(context, AppRouter.game, arguments: LevelId('${i + 1}'))`.
- **Test existente actualizado:** El helper `_host()` en `game_screen_test.dart` pasó de `const GameScreen()` a `GameScreen(levelId: LevelId('1'))` para compilar con la nueva firma requerida.
- `flutter analyze`: No issues found! `flutter test`: 106/106 verde (incluido el nuevo test de regresión BUG-2).
- App verificada corriendo: arranca, navega a Select Level, entra al juego y renderiza el tablero con flechas.
**Modificaciones realizadas por el equipo:**

## Entrada 001 — Phase 0: Eliminación dominio viejo y stubs de compilación

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Crear la rama `feat/main-sprint` y limpiar el dominio anterior (`board`/`player`, `GameController`, `CellWidget`) del proyecto Flutter, reemplazando los archivos que siguen siendo referenciados con stubs mínimos que compilan sin errores.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development)
**Prompt o instrucción proporcionada:** > "Execute Phase 0 of the Main Sprint plan: create feat/main-sprint branch in both repos, remove old game domain from Flutter front, replace six files with compile-only stubs, verify builds, and commit."
**Resultado obtenido:** 
- Eliminados: `lib/domain/board/`, `lib/domain/player/`, `rotate_arrow_use_case.dart`, `check_win_condition_use_case.dart`, `move_player_use_case.dart`, `move_command.dart`, `rotate_command.dart`, `level_repository_impl.dart`, `game_controller.dart`, `cell_widget.dart`.
- Reemplazados con stubs mínimos: `direction.dart`, `position.dart` (con `row`/`col`), `command.dart` (`abstract interface class ICommand`), `command_invoker.dart`, `game_screen.dart`, `board_widget.dart`.
- `flutter analyze`: No issues found.
- `flutter test`: 1/1 passed (widget_test).
**Modificaciones realizadas por el equipo:**

## Entrada 002 — Task 2B.1: Jerarquía de excepciones de dominio (Dart puro)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Crear la jerarquía de excepciones de dominio del front (Clean Mobile Architecture, capa `domain` en Dart puro sin Flutter/Hive/Riverpod) que usarán los Value Objects, entidades y casos de uso para señalar violaciones de invariantes y recursos no encontrados.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.1 (Domain: Excepciones Dart puro): clase base abstracta `DomainException implements Exception` con `message` y `toString()`, más seis subclases (`InvalidPositionException`, `InvalidArrowException`, `InvalidLevelIdException`, `InvalidMoveCountException`, `ArrowNotFoundException`, `LevelNotFoundException`) bajo `lib/domain/core/exceptions/`, siguiendo TDD (RED/GREEN) con tests AAA."
**Resultado obtenido:**
- Creada clase base abstracta `DomainException implements Exception` en `lib/domain/core/exceptions/domain_exception.dart` con campo `message` const y `toString() => '$runtimeType: $message'`.
- Creadas seis subclases concretas (`InvalidPositionException`, `InvalidArrowException`, `InvalidLevelIdException`, `InvalidMoveCountException`, `ArrowNotFoundException`, `LevelNotFoundException`), cada una con constructor const reenviando el mensaje vía `super.message`.
- Añadido `test/domain/core/exceptions/domain_exception_test.dart` (AAA): verifica `isA<Exception>`/`isA<DomainException>`, propagación del mensaje y formato de `toString()` por cada subclase.
- TDD: RED confirmado (los tests no compilaban sin las clases), luego GREEN (9/9 del archivo, 10/10 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 003 — Task 2B.2: Value Objects de dominio (Equatable, Dart puro)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar los Value Objects inmutables del dominio del front (Clean Mobile Architecture, capa `domain` en Dart puro): `Position`, `Direction`, `ArrowId`, `ArrowLength`, `LevelId`, `MoveCount` y `Email`. Cada VO valida sus invariantes en el constructor y deriva su igualdad de `Equatable.props`. Se aplica el override de taxonomía D1 (bounded contexts) sobre las rutas literales del plan.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.2 (Domain: Value Objects) siguiendo TDD (RED/GREEN) con tests AAA: crear los VOs inmutables con Equatable; `MoveCount.increment()` retorna nueva instancia; respetar el override de layout (arrow_id/arrow_length en `arrows/value_objects/`, level_id en `board/value_objects/`, position/direction/move_count en `game_core/value_objects/`, email en `auth/value_objects/`)."
**Resultado obtenido:**
- Reemplazado el stub `lib/domain/game_core/value_objects/position.dart` por el VO Equatable completo (`row`/`col`, valida `>= 0` → `InvalidPositionException`).
- `direction.dart` conservado (enum `up|down|left|right`).
- Creados `lib/domain/game_core/value_objects/move_count.dart` (`const`, `increment()` → nueva instancia con `value+1`), `lib/domain/arrows/value_objects/arrow_id.dart` (`const`, no valida), `lib/domain/arrows/value_objects/arrow_length.dart` (valida `>= 1` → `InvalidArrowException`), `lib/domain/board/value_objects/level_id.dart` (valida no-vacío → `InvalidLevelIdException`) y `lib/domain/auth/value_objects/email.dart` (regex → `ArgumentError`, igualdad case-insensitive).
- Override de layout D1 aplicado: `arrow_id`/`arrow_length` en contexto `arrows/`, `level_id` en contexto `board/`; imports relativos a `core/exceptions/` corregidos a la ubicación overridden. Imports de test usan el nombre real del paquete `flutter_arrow_maze`.
- Tests AAA (`position_test.dart`, `arrow_length_test.dart`, `move_count_test.dart`). TDD: RED confirmado (stub sin params nombrados y archivos inexistentes), luego GREEN (10/10 del directorio de VOs, 20/20 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 004 — Task 2B.3: Entidad Arrow y Aggregate Root ArrowBoard (Dart puro)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar la entidad `Arrow` y el Aggregate Root `ArrowBoard` del dominio del front (Clean Mobile Architecture, capa `domain` en Dart puro). `Arrow` modela una flecha multi-celda con `id`, `tail`, `direction`, `length` y propiedades calculadas `head`, `cells` y `exitPath(cols, rows)`. `ArrowBoard` es el único punto de acceso al estado del tablero: expone `canExit(ArrowId)`, `removeArrow(ArrowId)` (retorna un nuevo board inmutable) e `isCleared`; nadie accede a `Arrow` directamente, todo pasa por el agregado.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.3 (Domain: Arrow entity + ArrowBoard Aggregate Root) siguiendo TDD (RED/GREEN) con tests AAA: `Arrow` con `head`/`cells`/`exitPath` por dirección; `ArrowBoard` con `canExit`/`removeArrow`/`isCleared` y detección de bloqueo por celdas ocupadas; respetar el override de layout D1 (arrow_id/arrow_length en `arrows/value_objects/`)."
**Resultado obtenido:**
- Creado `lib/domain/arrows/entities/arrow.dart`: entidad `Equatable` inmutable. `head` calcula la última celda según `direction`; `cells` genera todas las posiciones ocupadas en orden; `exitPath(cols, rows)` devuelve las celdas libres que la flecha debe recorrer hasta el borde (vacío si la cabeza ya está en el borde).
- Creado `lib/domain/arrows/entities/arrow_board.dart`: Aggregate Root `Equatable`. `canExit` comprueba que ninguna celda de `exitPath` esté en el conjunto de celdas ocupadas por las demás flechas; `removeArrow` retorna un `ArrowBoard` nuevo sin esa flecha; `isCleared` es `true` cuando no quedan flechas. Comentario inline documenta el patrón Aggregate Root.
- Override de layout D1 aplicado: imports de `arrow_id`/`arrow_length` resueltos a `arrows/value_objects/` (no a `game_core/value_objects/` como en el literal del plan); `position`/`direction` siguen en `game_core/value_objects/`. Imports de test usan el nombre real del paquete `flutter_arrow_maze` (el plan literal usaba un placeholder `maze_prueba_front`).
- Tests AAA (`test/domain/entities/arrow_test.dart` 4 casos, `test/domain/entities/arrow_board_test.dart` 5 casos). TDD: RED confirmado (entidades inexistentes), luego GREEN (9/9 del directorio de entidades, 29/29 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 005 — Task 2B.4: Puertos de dominio (ILevelProgressRepository, ILevelGenerator)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Definir los puertos (interfaces Dart puro) que la infraestructura implementará en tareas posteriores: `ILevelProgressRepository` (persistencia de progreso/finalización por nivel) e `ILevelGenerator` (generación de tableros solucionables). Aplican la Regla de Dependencia (DIP): el dominio depende solo de abstracciones; las implementaciones concretas (Hive, generador DAG) se inyectan desde fuera.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.4 (Domain: Ports) siguiendo TDD (RED/GREEN) con tests AAA. Crear `ILevelProgressRepository` con getProgress/saveProgress/markCompleted/isCompleted e `ILevelGenerator` con generate(cols, rows, arrowCount). Respetar el override de layout D1 (level_id en `board/value_objects/`, move_count en `game_core/value_objects/`)."
**Resultado obtenido:**
- Creado `lib/domain/board/repositories/i_level_progress_repository.dart`: `abstract interface class ILevelProgressRepository` con `getProgress(LevelId) -> Future<MoveCount?>`, `saveProgress(LevelId, MoveCount)`, `markCompleted(LevelId)`, `isCompleted(LevelId) -> Future<bool>`.
- Creado `lib/domain/arrows/services/i_level_generator.dart`: `abstract interface class ILevelGenerator` con `generate({required int cols, required int rows, required int arrowCount}) -> ArrowBoard` (tablero solucionable por construcción DAG).
- Override de layout D1 aplicado: el import de `LevelId` se resolvió a `board/value_objects/level_id.dart` (no a `game_core/value_objects/` como en el literal del plan); `MoveCount` permanece en `game_core/value_objects/move_count.dart`.
- Tests de contrato AAA con fakes/stubs en memoria que implementan cada puerto (verifican sustituibilidad LSP y la superficie de la interfaz): `test/domain/repositories/i_level_progress_repository_test.dart` (4 casos), `test/domain/services/i_level_generator_test.dart` (2 casos). TDD: RED confirmado (puertos inexistentes -> fallo de compilación), luego GREEN (6/6 de los nuevos tests, 35/35 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 006 — Task 2B.5: Application — RemoveArrowUseCase

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar el caso de uso de aplicación `RemoveArrowUseCase`, que orquesta la mecánica central del juego: dada una `ArrowBoard` y un `ArrowId`, devuelve `Right(newBoard)` si la flecha puede salir (camino libre hasta el borde) o `Left(DomainException)` si está bloqueada. Actúa como fachada de aplicación sobre la lógica del Aggregate Root (`canExit`/`removeArrow`), sin filtrar reglas de dominio a la presentación.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.5 (Application: RemoveArrowUseCase) siguiendo TDD (RED/GREEN) con tests AAA. `execute(ArrowBoard, ArrowId)` devuelve `Either<DomainException, ArrowBoard>`: Right si `canExit`, Left (`ArrowNotFoundException`) si bloqueada. Respetar el override de layout D1 (arrow_id en `arrows/value_objects/`)."
**Resultado obtenido:**
- Creado `lib/application/use_cases/remove_arrow_use_case.dart`: clase `RemoveArrowUseCase` con `Either<DomainException, ArrowBoard> execute(ArrowBoard board, ArrowId arrowId)`. Si `!board.canExit(arrowId)` -> `Left(ArrowNotFoundException(...))`; en otro caso `Right(board.removeArrow(arrowId))`. Usa `dartz.Either` para el flujo funcional de error sin excepciones lanzadas.
- Override de layout D1 aplicado: el import de `ArrowId` se resolvió a `arrows/value_objects/arrow_id.dart` (no a `game_core/value_objects/` como en el literal del plan).
- Adaptación al repo: el prefijo de paquete del plan (`maze_prueba_front`) se corrigió al nombre real del paquete (`flutter_arrow_maze`) en los imports del test.
- Test AAA: `test/application/use_cases/remove_arrow_use_case_test.dart` (2 casos: salida exitosa -> Right con tablero limpio; flecha bloqueada por otra flecha en el camino de salida -> Left<DomainException>). TDD: RED confirmado (caso de uso inexistente -> fallo de compilación), luego GREEN (2/2 de los nuevos tests, 37/37 suite completa). `flutter analyze`: No issues found.
**Modificaciones realizadas por el equipo:**

## Entrada 007 - Task 2B.5 (fix): distinguir id ausente de salida bloqueada

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Hallazgo de revision (important) sobre `RemoveArrowUseCase`: `ArrowBoard.canExit` devuelve `false` por dos condiciones distintas (id inexistente vs. flecha presente pero camino bloqueado). El codigo original colapsaba ambas en `Left(ArrowNotFoundException('... path is blocked'))`, contradictorio en los dos casos (tipo "not found" para el caso comun de juego; mensaje "path is blocked" para un id realmente ausente). La presentacion no podia distinguir un error de programacion de un movimiento invalido legitimo. Es un defecto inducido por el literal del plan (lineas 2544-2546), marcado como origen para enmendar el plan.
**Herramienta de IA utilizada:** Claude Code (opus)
**Prompt o instruccion proporcionada:** > "Corregir hallazgos de revision de 2B.5: distinguir id ausente (ArrowNotFoundException) de flecha bloqueada (InvalidMoveException); reejecutar tests; commit fix(...)."
**Resultado obtenido:**
- Anadido `bool contains(ArrowId)` al Aggregate Root `ArrowBoard` (la pertenencia es conocimiento del AR; antes solo existia el privado `_findById`). Permite al caso de uso desambiguar sin iterar la lista de arrows fuera del agregado.
- Creada excepcion dedicada `lib/domain/core/exceptions/invalid_move_exception.dart` (`InvalidMoveException`) para el resultado legitimo "presente pero bloqueado", distinta de `InvalidMoveCountException` (validacion de conteo) y de `ArrowNotFoundException` (error de programacion).
- `RemoveArrowUseCase.execute` ahora ramifica por pertenencia primero: id ausente -> `Left(ArrowNotFoundException('Arrow <id> not found on the board'))`; presente pero bloqueada -> `Left(InvalidMoveException('Arrow <id> cannot exit - path is blocked'))`; camino libre -> `Right(board.removeArrow(id))`. Tipo y mensaje coherentes en cada rama.
- Tests: el caso bloqueado asevera `isA<InvalidMoveException>()`; nuevo caso para id ausente asevera `isA<ArrowNotFoundException>()`; dos tests para `contains`; `InvalidMoveException` anadida a la jerarquia de excepciones. GREEN: 20/20 del area afectada, 41/41 suite completa, salida pristina.
**Modificaciones realizadas por el equipo:**

## Entrada 008 — Task 2B.6: Application — Command Pattern (ICommand, CommandInvoker, RemoveArrowCommand)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar el patron Command en la capa de aplicacion del front para encapsular operaciones reversibles sobre `ArrowBoard`. `ICommand` define el contrato (execute/undo ambos retornan `ArrowBoard`); `RemoveArrowCommand` implementa el comando de quitar una flecha con soporte de undo via snapshot; `CommandInvoker` gestiona el historial y expone `executeCommand`, `undo` y `canUndo`.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, sonnet)
**Prompt o instruccion proporcionada:** > "Implementar Task 2B.6 (Application: Command Pattern) siguiendo TDD (RED/GREEN) con tests AAA. Crear ICommand con execute/undo que retornan ArrowBoard; RemoveArrowCommand con snapshot para undo; CommandInvoker con historial de snapshots. Respetar override de layout D1 (arrow_id/arrow_length en arrows/value_objects/)."
**Resultado obtenido:**
- `lib/application/commands/command.dart`: Reemplazado stub. `abstract interface class ICommand` con `execute(ArrowBoard) -> ArrowBoard` y `undo(ArrowBoard) -> ArrowBoard`. Comentario inline documenta el patron.
- `lib/application/commands/remove_arrow_command.dart`: Creado. `RemoveArrowCommand implements ICommand`; almacena snapshot de la `Arrow` eliminada en `execute` y la restaura en `undo`.
- `lib/application/commands/command_invoker.dart`: Reemplazado stub. `CommandInvoker` mantiene historial `List<(ICommand, ArrowBoard)>` (command + board-before-execute). `undo` devuelve el `boardBefore` directamente (snapshot-based), evitando acumulacion incorrecta al llamar desde UI con board arbitrario.
- Override de layout D1 aplicado: test usa `arrows/value_objects/arrow_id.dart` y `arrows/value_objects/arrow_length.dart`; package name `flutter_arrow_maze` (no `maze_prueba_front` como en el literal del plan).
- Desviacion justificada: `undo` usa snapshot del estado anterior en vez de `command.undo(currentBoard)` para alinear con el test del plan (que pasa el board original a `undo`, no el cleared). Diseno mas robusto y predecible.
- Tests AAA: `test/application/commands/command_invoker_test.dart` (3 casos: canUndo vacio, execute aplica y registra, undo restaura). TDD: RED confirmado (clases inexistentes/incompletas), GREEN (3/3 nuevos, 44/44 suite completa). `flutter analyze`: No issues found.
**Modificaciones realizadas por el equipo:**

## Entrada 009 — Task 2B.6 (fix): restaurar el diseno Command del plan (delegacion de undo)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Corregir hallazgos de revision sobre el patron Command (2B.6). El `CommandInvoker` almacenaba tuplas `List<(ICommand, ArrowBoard)>` y `undo` devolvia el `boardBefore` guardado directamente, dejando `RemoveArrowCommand.undo` como codigo muerto y rompiendo el patron Command. El test ademas asertaba el bug (pasaba el board PRE-execute a `undo`). Se restaura el diseno exacto del plan: el invoker guarda `List<ICommand>` y delega `undo(currentBoard)` al comando.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instruccion proporcionada:** > "Arreglar hallazgos de revision de 2B.6: CommandInvoker debe almacenar List<ICommand> y delegar undo al comando exactamente como especifica el plan; el test debe pasar el board post-execute a undo y verificar que command.undo realmente se invoca y restaura desde el board actual; documentar que RemoveArrowCommand es single-use."
**Resultado obtenido:**
- `lib/application/commands/command_invoker.dart`: Reescrito. Ahora `final List<ICommand> _history`; `undo(currentBoard)` hace pop del ultimo comando y retorna `command.undo(currentBoard)` (delegacion). Se elimina el almacenamiento de snapshots de tableros.
- `lib/application/commands/remove_arrow_command.dart`: Anadido doc-comment que documenta que las instancias son single-use (el snapshot `_removedArrow` se sobrescribe en cada `execute`; `undo` antes de `execute` devuelve el tablero sin cambios) y que `undo` reinserta la flecha en el tablero ACTUAL recibido.
- `test/application/commands/command_invoker_test.dart`: Corregido. El caso de undo pasa el tablero POST-execute (mutado adicionalmente removiendo a2) para distinguir delegacion real de la devolucion de un snapshot obsoleto; ademas verifica el caso "nada que deshacer" (devuelve el mismo board por identidad).
- TDD: RED confirmado contra el invoker bugueado (Expected [a1], Actual [a1, a2] — devolvia el snapshot obsoleto con a2); GREEN tras delegar (4/4 nuevos casos, 45/45 suite completa). `flutter analyze`: No issues found.
**Modificaciones realizadas por el equipo:**

## Entrada 010 — Task 2B.7: GameState sealed + GameController (AsyncNotifier Riverpod)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Implementar la fachada reactiva de la capa application: una jerarquia sellada GameState (GameLoading | GamePlaying | GameWon) y un GameController (AsyncNotifier<GameState>) con loadLevel, tapArrow y undoMove. Las dependencias (ILevelGenerator, RemoveArrowUseCase, CommandInvoker) se inyectan por constructor para mantener los use cases libres del framework (DIP) y sustituibles en tests.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.7 (TDD/AAA): GameState sellado y GameController AsyncNotifier con loadLevel/tapArrow/undoMove, dependencias inyectadas por constructor, sin construir CommandInvoker directamente."
**Resultado obtenido:**
- `lib/application/state/game_state.dart`: Creado. `sealed class GameState` con `GameLoading`, `GamePlaying(board, moves)` y `GameWon(moves)`. Comentario inline documenta el patron State sellado (pattern matching exhaustivo en la UI).
- `lib/application/state/game_controller.dart`: Creado. `GameController extends AsyncNotifier<GameState>`; constructor inyecta `ILevelGenerator`, `RemoveArrowUseCase` y `CommandInvoker`. `loadLevel` genera el tablero y emite `GamePlaying`; `tapArrow` valida con el use case (Either) y, solo si es legal, ejecuta el `RemoveArrowCommand` via `CommandInvoker.executeCommand` (una sola ejecucion, evitando el doble-execute del literal del plan que sobreescribia el snapshot de undo), emitiendo `GameWon` si el tablero queda limpio; `undoMove` delega en `_invoker.undo`.
- `gameControllerProvider`: `AsyncNotifierProvider` cuya fabrica por defecto lanza `UnimplementedError` (se compone en core/DI o se sobreescribe en tests), evitando acoplar este archivo a impls concretas inexistentes (ILevelGenerator real) y respetando DIP.
- `test/application/state/game_controller_test.dart`: 3 tests AAA (loadLevel -> GamePlaying; tapArrow path libre -> GameWon; undoMove restaura GamePlaying con la flecha reinsertada). Mock de `ILevelGenerator` via mockito `@GenerateMocks` + build_runner (`game_controller_test.mocks.dart`).
- Desviaciones del literal del plan (justificadas): (1) package name correcto `flutter_arrow_maze` (no `maze_prueba_front`); (2) layout D1-estricto en imports — `arrows/value_objects/arrow_id.dart`, `arrows/value_objects/arrow_length.dart`, `board/value_objects/level_id.dart` (no todos bajo game_core); (3) `loadLevel` hace `await future` antes de mutar el estado para evitar que la microtask de `build()` sobreescriba el `GamePlaying` recien fijado (race de AsyncNotifier); (4) `tapArrow` ejecuta el comando una sola vez via el invoker.
- TDD: RED (clases inexistentes) -> GREEN (3/3 nuevos). `flutter analyze`: No issues found. `flutter test`: 48/48.
**Modificaciones realizadas por el equipo:**

## Entrada 011 — Task 2B.8: Infrastructure — Hive LevelProgress (DataSource + Model + Repository)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Implementar la persistencia local del progreso de niveles en la capa de infraestructura siguiendo el patron Petros Efthymiou (DataSource vs Repository): un modelo Hive, un DataSource que encapsula el acceso raw a Hive, y un Repository que implementa el puerto de dominio ILevelProgressRepository mapeando los Value Objects LevelId/MoveCount a/desde el modelo. La separacion permite testear el Repository de forma aislada mockeando el DataSource sin abrir cajas Hive reales.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.8 (TDD/AAA): LevelProgressHiveModel (@HiveType typeId 0), HiveLocalDataSource (getProgress/saveProgress/markCompleted/isCompleted) y HiveProgressRepository implements ILevelProgressRepository consumiendo el DataSource, nunca Hive directamente. Genera el TypeAdapter con build_runner y commitea los .g.dart."
**Resultado obtenido:**
- `lib/infrastructure/models/level_progress_hive_model.dart`: Creado. `@HiveType(typeId: 0) class LevelProgressHiveModel extends HiveObject` con campos `levelId` (HiveField 0), `moveCount` (HiveField 1), `completed` (HiveField 2). Modelo de persistencia puro de infraestructura; el dominio nunca lo conoce.
- `lib/infrastructure/data_sources/local/hive_level_progress_data_source.dart`: Creado. `HiveLocalDataSource` encapsula el acceso raw a `Hive.box<LevelProgressHiveModel>('level_progress')`. Metodos `getProgress`, `saveProgress`, `markCompleted`, `isCompleted`. Comentario inline documenta el patron Petros Efthymiou (DataSource testeable/sustituible).
- `lib/infrastructure/repositories/hive_progress_repository.dart`: Creado. `HiveProgressRepository implements ILevelProgressRepository` (puerto de dominio). Adapter que mapea `LevelId.value`/`MoveCount.value` <-> modelo Hive delegando en el DataSource; nunca toca Hive directamente (DIP, regla de dependencias infraestructura -> dominio). Comentario inline documenta el patron Adapter.
- `lib/infrastructure/models/level_progress_hive_model.g.dart` + `lib/hive_registrar.g.dart`: generados por hive_ce_generator (TypeAdapter y registrar de adapters). El registrar viene marcado por el generador como "Check in to version control".
- `test/infrastructure/repositories/hive_progress_repository_test.dart` (+ `.mocks.dart`): 6 tests AAA mockeando `HiveLocalDataSource` (mockito `@GenerateMocks`): getProgress mapea modelo a MoveCount; getProgress devuelve null cuando no hay registro; saveProgress/markCompleted delegan los valores desempaquetados; isCompleted devuelve true/false segun el DataSource.
- Desviacion del literal del plan (justificada): el import de `LevelId` es `domain/board/value_objects/level_id.dart` (layout D1-estricto y firma real del puerto), no `game_core` como mostraba el snippet del plan. Package name correcto `flutter_arrow_maze`.
- TDD: RED (clases inexistentes) -> GREEN (6/6 nuevos). `flutter analyze`: No issues found. `flutter test`: 54/54.
**Modificaciones realizadas por el equipo:**

## Entrada 012 — Task 2B.9: Infrastructure — GraphBoardGenerator (DAG, solvabilidad por construccion)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Implementar un generador procedimental de tableros que garantice solvabilidad sin backtracking. El algoritmo DAG coloca las flechas de una en una y solo acepta una flecha candidata si, en el instante de su colocacion, ya puede salir del tablero (`tempBoard.canExit`). Como cada flecha colocada despues nunca bloquea a las anteriores que ya tenian salida libre, el orden inverso de colocacion es siempre un orden de resolucion valido: el tablero es solucionable por construccion. Acepta una `seed` opcional para reproducibilidad determinista.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.9 (TDD/AAA): GraphBoardGenerator implements ILevelGenerator con algoritmo DAG (coloca cada flecha solo si puede salir en el momento de colocacion -> solvabilidad garantizada). Constructor con seed opcional para determinismo. Tres tests: cuenta de flechas solicitada, tablero solucionable (resolver repetidamente con RemoveArrowUseCase hasta isCleared), y misma seed -> mismo tablero."
**Resultado obtenido:**
- `lib/infrastructure/generators/graph_board_generator.dart`: Creado. `class GraphBoardGenerator implements ILevelGenerator` (puerto de dominio `domain/arrows/services/i_level_generator.dart`). `generate({cols, rows, arrowCount})` usa `Random(seed)`; en cada intento genera una flecha candidata (`_randomArrow`), construye un `ArrowBoard` temporal con la candidata y solo la acepta si `tempBoard.canExit(candidate.id)` (invariante DAG). `maxAttempts = 500` evita bucles infinitos en configuraciones densas. `_randomArrow` elige direccion/longitud aleatorias y calcula el rango valido de la cola (tail) por direccion via pattern matching `switch`, devolviendo `null` cuando el tablero es demasiado pequeno para la longitud. Comentario inline documenta el patron/algoritmo DAG (solvabilidad por construccion, sin backtracking).
- `test/infrastructure/generators/graph_board_generator_test.dart`: Creado. 3 tests AAA: (1) genera el numero solicitado de flechas; (2) tablero solucionable — bucle que en cada paso exige `isNotEmpty` el conjunto de flechas con `canExit` y las remueve con `RemoveArrowUseCase` hasta `isCleared`; (3) misma seed (42) produce flechas identicas (igualdad por Equatable).
- Desviacion del literal del plan (justificada): el snippet del plan importaba `arrow_id`/`arrow_length` desde `domain/game_core/value_objects/` y usaba el prefijo de package `maze_prueba_front`. El layout D1-estricto real ubica esos VO de flecha en `domain/arrows/value_objects/` y el package es `flutter_arrow_maze`. Se usaron las rutas y el nombre de package reales (verificados contra el codigo commiteado).
- TDD: RED (clases inexistentes) -> GREEN (3/3 nuevos). `flutter analyze`: No issues found! `flutter test`: 57/57.
**Modificaciones realizadas por el equipo:**

## Entrada 013 — Task 2B.10: Core — AOP Logger + Theme (light/dark) + AppRouter

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Crear la capa `core/` transversal del front: el puerto de logging AOP `ILoggerService` con su adapter sobre el package `logger`, la paleta `AppColors` y los `ThemeData` claro/oscuro (`AppTheme.light()`/`AppTheme.dark()`), y la tabla de rutas nombradas `AppRouter`. Se aplican las decisiones de UI aprobadas (paleta dark-neon con fondo casi-negro neutro `#0A0A0C` y contraparte clara frosted-on-light, para `ThemeMode.system`), que gobiernan sobre los hex del plan.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.10 (TDD/AAA): ILoggerService + LoggerServiceAdapter (AOP, patron Adapter sobre el package logger), AppColors con los hex aprobados, AppTheme.light() Y AppTheme.dark() para ThemeMode.system, y AppRouter con onGenerateRoute. flutter analyze 0 issues y flutter test verde."
**Resultado obtenido:**
- `lib/core/aspects/i_logger_service.dart`: Creado. `abstract interface class ILoggerService` con `log/error/warn`. Puerto AOP: la logica de negocio depende de esta abstraccion (DIP), nunca del package concreto.
- `lib/core/aspects/logger_service_adapter.dart`: Creado. `LoggerServiceAdapter implements ILoggerService` adaptando el package `logger` (patron Adapter, documentado inline). Constructor con `Logger?` inyectable para permitir testeo aislado.
- `lib/core/theme/app_colors.dart`: Creado. Constantes `Color` con los hex EXACTOS de la decision UI 2026-06-17: dark (background `#0A0A0C`, surface `#141417`, primary cyan `#22D3EE`, secondary purpura `#A855F7`, flechas por direccion, estados) y light (background `#F4F4F6`, acentos profundizados). Fuente unica de verdad de color.
- `lib/core/theme/app_theme.dart`: Creado. `AppTheme.light()` y `AppTheme.dark()` retornan `ThemeData` (Material3) construyendo `ColorScheme` explicitos (sin los campos `background`/`onBackground` deprecados). Override del plan que solo definia dark: ahora ambos para `ThemeMode.system`.
- `lib/core/router/app_router.dart`: Creado. `AppRouter` con constantes `home`/`levelSelection`/`game`/`victory` y `onGenerateRoute` (switch expression con fallback a Home). Centraliza la navegacion (SRP) y desacopla las pantallas por nombre de ruta.
- Colateral del fragmento (necesario para que el router compile): stubs minimos `lib/presentation/home/screens/home_screen.dart`, `lib/presentation/level_selection/level_selection_screen.dart` y `lib/presentation/level_selection/victory_screen.dart` (marcados "implementado en Task 2B.13"), siguiendo el patron del stub `game_screen.dart` ya existente.
- Tests AAA: `test/core/aspects/logger_service_adapter_test.dart` (5 tests, mockito sobre `Logger`: verifica formato `[context] message` y forwarding del error); `test/core/theme/app_theme_test.dart` (2 tests: brillo, scaffold y acentos por tema); `test/core/router/app_router_test.dart` (6 tests: cada ruta construye su pantalla, fallback a Home, constantes de ruta).
- TDD: RED (clases inexistentes) -> GREEN. `flutter analyze`: No issues found! `flutter test`: 70/70 (13 nuevos).
**Modificaciones realizadas por el equipo:**

## Entrada 014 — Task 2B.11: Presentation — Providers (DI Riverpod, composition root)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Crear el composition root de la capa `presentation/`: los providers Riverpod que instancian las clases de `infrastructure/` (unico lugar autorizado para ello) y exponen sus abstracciones (`ILoggerService`, `HiveLocalDataSource`, `ILevelProgressRepository`, `ILevelGenerator`) a la app por inyeccion. Mas un `game_provider.dart` que re-exporta `gameControllerProvider` para que la presentation importe el estado de juego desde un unico punto.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.11 (TDD/AAA): dependency_providers.dart con providers para ILoggerService, HiveLocalDataSource, ILevelProgressRepository y ILevelGenerator (DIP, unico sitio que instancia infrastructure/), y game_provider.dart re-exportando gameControllerProvider. flutter analyze 0 issues y flutter test verde."
**Resultado obtenido:**
- `lib/presentation/providers/dependency_providers.dart`: Creado. Composition root (DIP) con `loggerServiceProvider` (singleton AOP `LoggerServiceAdapter`), `hiveDataSourceProvider` (`HiveLocalDataSource`), `levelProgressRepositoryProvider` (`HiveProgressRepository` recibiendo el data source via `ref.watch`, patron Petros DataSource/Repository separados) y `levelGeneratorProvider` (`GraphBoardGenerator`). Comentario inline documentando que es el unico lugar donde se instancia `infrastructure/`.
- `lib/presentation/providers/game_provider.dart`: Creado. `export ... show gameControllerProvider` (facade): la presentation importa el estado de juego desde un solo punto sin alcanzar directamente `application/state/`.
- Tests AAA: `test/presentation/providers/dependency_providers_test.dart` (5 tests con `ProviderContainer` aislado: cada provider resuelve su tipo concreto y su abstraccion; los providers son singletons dentro del mismo contenedor via `identical`).
- TDD: RED (providers inexistentes) -> GREEN. `flutter analyze`: No issues found! `flutter test`: 75/75 (5 nuevos).
**Modificaciones realizadas por el equipo:**

## Entrada 015 — Task 2B.12: Presentation — ArrowPainter (CustomPainter procedural con glow 3D)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Crear el `ArrowPainter` (CustomPainter) que dibuja flechas multi-celda de forma procedural sobre el `Canvas` (sin SVG ni assets), con la profundidad 3D aprobada en la decision UI 2026-06-17: cuerpo de color por direccion, sombra proyectada, bisel/relieve, punta triangular clara y glow purpura al resaltar.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.12 (TDD/AAA, skill algorithmic-art): lib/presentation/game/painters/arrow_painter.dart, CustomPainter procedural con efecto glow. flutter analyze 0 issues y flutter test verde."
**Resultado obtenido:**
- `lib/presentation/game/painters/arrow_painter.dart`: Creado. `ArrowPainter extends CustomPainter` con `arrow`, `cellSize`, `isHighlighted`. `paint` traza el cuerpo via `Path` (centro de cada celda de `arrow.cells`) con `strokeCap.round`, capa de glow (`MaskFilter.blur`) cuando esta resaltada, sombra proyectada (offset abajo-derecha difuminado), bisel claro (offset arriba-izquierda) y punta triangular (`_drawHead` orientada por `arrow.direction`). `shouldRepaint` solo repinta si cambia `arrow` o `isHighlighted` (rendimiento).
- Desvio respecto al codigo literal del plan, gobernado por la decision UI 2026-06-17 y el layout D1: el plan referenciaba `AppColors.arrowBody`/`arrowHighlight` (inexistentes). La paleta aprobada define color de flecha POR DIRECCION; por ello se anade `ArrowPainter.bodyColorFor(Direction)` (mapea a `AppColors.arrowUp/Down/Left/Right`, fuente unica de verdad de color) y se completa la profundidad 3D (sombra+bisel) que pedia el doc UI. Se anadio el token `AppColors.arrowHighlight` (`#F8FAFC`) para el cuerpo resaltado.
- `lib/core/theme/app_colors.dart`: Modificado. Nuevo token `arrowHighlight`.
- Tests AAA: `test/presentation/game/painters/arrow_painter_test.dart` (10 tests: `bodyColorFor` mapea cada direccion a su color; `shouldRepaint` false sin cambios y true al cambiar flecha o highlight; `paint` no lanza para cada direccion, con highlight y para flecha de 1 celda, usando `PictureRecorder`/`Canvas`).
- TDD: RED (clase inexistente) -> GREEN. `flutter analyze`: No issues found! `flutter test`: 85/85 (10 nuevos).
**Modificaciones realizadas por el equipo:**

## Entrada 016 — Task 2B.13: Presentation — Screens (HomeScreen, LevelSelectionScreen, VictoryScreen)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Implementar las tres pantallas de flujo de la app sustituyendo los stubs: `HomeScreen` (titulo neon + CTA "Play"), `LevelSelectionScreen` (cuadricula de 12 niveles glassmorphism) y `VictoryScreen` (tablero limpiado + movimientos). Pura presentacion: navegan por nombre de ruta (`AppRouter`) sin conocer la clase destino y sin alcanzar `infrastructure/` ni `domain/`.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.13 (TDD/AAA): HomeScreen, LevelSelectionScreen y VictoryScreen. Dark-neon con glassmorphism y ThemeMode.system (light Y dark). flutter analyze 0 issues y flutter test verde."
**Resultado obtenido:**
- `lib/presentation/home/screens/home_screen.dart`: Implementado. Titulo "Arrow Maze" con glow neon (Shadow sobre `primary`), tagline "Clear the board" en texto muted y `FilledButton` "Play" -> `AppRouter.levelSelection`.
- `lib/presentation/level_selection/level_selection_screen.dart`: Implementado. `GridView.builder` de 12 tiles glassmorphism (relleno translucido `glassFill` + borde sutil `glassBorder`); cada `InkWell` navega a `AppRouter.game`.
- `lib/presentation/level_selection/victory_screen.dart`: Implementado. Icono estrella `AppColors.success`, "Board Cleared!", `$moves moves` leido de `ModalRoute...settings.arguments as int? ?? 0`, y CTA "Back to Levels" via `pushNamedAndRemoveUntil`.
- Desvio respecto al codigo literal del plan, gobernado por la decision UI 2026-06-17: el plan referenciaba `AppColors.onSurface` y `AppColors.arrowBody` (inexistentes). Se usan los tokens reales de la paleta aprobada (`onSurfaceMuted` para subtexto, `onBackground` para texto, `glassFill`/`glassBorder` para paneles). Las tres pantallas resuelven sus colores segun `Theme.of(context).brightness` para cumplir `ThemeMode.system` (light Y dark), no solo-dark.
- Tests AAA: `test/presentation/home/home_screen_test.dart` (2: renderiza titulo/tagline/CTA; "Play" navega a LevelSelectionScreen via router real), `test/presentation/level_selection/level_selection_screen_test.dart` (3: cuadricula perezosa renderiza tile "1"; scroll revela "12"; tap navega a GameScreen), `test/presentation/level_selection/victory_screen_test.dart` (3: muestra movimientos de arguments; fallback a 0 sin arguments; "Back to Levels" vuelve a LevelSelectionScreen).
- TDD: RED (stubs) -> GREEN. `flutter analyze`: No issues found! `flutter test`: 93/93 (8 nuevos).
**Modificaciones realizadas por el equipo:**

## Entrada 017 — Task 2B.14: Presentation — Game Widgets + GameScreen (ArrowWidget, ExitingArrowWidget, BoardWidget, GameScreen)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Implementar la capa de juego de presentation sustituyendo los stubs: `ArrowWidget` (pieza tappable = GestureDetector sobre CustomPaint(ArrowPainter)), `ExitingArrowWidget` (animacion de salida SlideTransition + FadeTransition), `BoardWidget` (rejilla cols x rows que coloca una ArrowWidget por flecha y consume `gameControllerProvider`) y `GameScreen` (scaffold con tablero + contador de moves + boton undo, que navega a VictoryScreen al ganar). Pura presentation: depende solo de `application/` (estado reactivo Riverpod) y `core/`; nunca alcanza `infrastructure/` ni invoca dominio directamente.
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.14 (TDD/AAA): ArrowWidget, ExitingArrowWidget, BoardWidget y GameScreen. Consumen gameControllerProvider; GameScreen muestra moves y undo y navega a victory al ganar. Dark-neon con ThemeMode.system (light Y dark). flutter analyze 0 issues y flutter test verde."
**Resultado obtenido:**
- `lib/presentation/game/widgets/arrow_widget.dart`: Creado. `ArrowWidget extends StatelessWidget` (arrow, cellSize, isHighlighted, onTap). `GestureDetector(onTap)` sobre `CustomPaint(painter: ArrowPainter(...), size: Size.infinite)`. Sin logica de juego (SRP): solo enlaza el toque con el callback que provee el tablero.
- `lib/presentation/game/widgets/exiting_arrow_widget.dart`: Creado. `ExitingArrowWidget extends StatefulWidget` con `SingleTickerProviderStateMixin`; `AnimationController` (300ms) compone `SlideTransition` (offset segun `arrow.direction` via switch exhaustivo) + `FadeTransition` sobre el `ArrowPainter` resaltado; al completar invoca `onComplete`; `dispose` libera el controller. Comentario inline documenta el SRP de encapsular la animacion de salida.
- `lib/presentation/game/widgets/board_widget.dart`: Implementado (antes stub). `BoardWidget extends ConsumerWidget`; `ref.watch(gameControllerProvider).valueOrNull`; si no es `GamePlaying` -> `SizedBox.shrink()`. Panel `cols*72 x rows*72` y `Stack` con una `ArrowWidget` por flecha (key estable `ValueKey(arrow.id.value)`), cuyo `onTap` llama `ref.read(...notifier).tapArrow(arrow.id)`.
- `lib/presentation/game/screens/game_screen.dart`: Implementado (antes stub). `GameScreen extends ConsumerWidget`; `re-export ... gameControllerProvider`; AppBar con `Moves: N` (GamePlaying), `IconButton(Icons.undo) -> undoMove()`, body con `BoardWidget`/spinner/error via `asyncState.when`; `ref.listen` navega a `AppRouter.victory` con los moves al transitar a `GameWon`.
- Desvios respecto al codigo literal del plan (justificados): (1) layout D1-estricto — `ArrowId` se importa de `domain/arrows/value_objects/arrow_id.dart`, no `game_core`; `arrow.id` ya es `ArrowId` por lo que se pasa directo a `tapArrow` (sin re-envolver `ArrowId(arrow.id.value)`). (2) UI 2026-06-17 / ThemeMode.system: BoardWidget y GameScreen resuelven sus colores segun `Theme.of(context).brightness` (surface/border del panel; onSurface/accent/primary del AppBar) en vez de hardcodear solo-dark con tokens `AppColors.arrowBody` (inexistente). (3) BoardWidget importa el provider via `presentation/providers/game_provider.dart` (facade), no desde el screen.
- Colateral del fragmento: `test/presentation/level_selection/level_selection_screen_test.dart` se actualizo porque GameScreen paso de stub StatelessWidget a ConsumerWidget y su test de navegacion necesitaba ahora un `ProviderScope` con `gameControllerProvider` sobreescrito (generador falso de tablero vacio).
- Tests AAA: `test/presentation/game/widgets/arrow_widget_test.dart` (3: pinta via ArrowPainter; propaga isHighlighted; onTap), `test/presentation/game/widgets/exiting_arrow_widget_test.dart` (3: usa Slide/FadeTransition; onComplete al terminar; dispose sin fugas), `test/presentation/game/widgets/board_widget_test.dart` (3: nada si no juega; una ArrowWidget por flecha; tap consume una flecha), `test/presentation/game/screens/game_screen_test.dart` (2: contador de moves + undo; navega a VictoryScreen al limpiar el tablero). Provider sobreescrito con `GameController(_FakeLevelGenerator(), RemoveArrowUseCase(), CommandInvoker())` via `UncontrolledProviderScope`.
- TDD: RED (stubs) -> GREEN. `flutter analyze`: No issues found! `flutter test`: 104/104 (11 nuevos).
**Modificaciones realizadas por el equipo:**

## Entrada 018 — Task 2B.15: Bootstrap — main.dart (Hive init, ProviderScope, AppRouter, ThemeMode.system)

**Fecha:** 2026-06-18
**Tarea o problema abordado:** Cablear el composition root de la app en `lib/main.dart`: inicializar Hive (`initFlutter`), registrar los `TypeAdapter` y abrir el box de progreso `level_progress` antes de levantar `runApp`, y configurar el `MaterialApp` con `AppRouter` (rutas nombradas) y los temas de `AppTheme`. Mantener el wiring de infraestructura en `main` deja `presentation/` libre de detalles de persistencia (DIP).
**Herramienta de IA utilizada:** Claude Code (Opus)
**Prompt o instruccion proporcionada:** > "Implementa la task 2B.15 (TDD/AAA): actualiza main.dart para inicializar Hive, abrir el box level_progress, registrar el adapter, arrancar ProviderScope y wirear AppRouter + temas. flutter analyze 0 issues y flutter test verde."
**Resultado obtenido:**
- `lib/main.dart`: Reescrito. `main()` async: `WidgetsFlutterBinding.ensureInitialized()`, `await Hive.initFlutter()`, `Hive.registerAdapters()` (extension generada en `hive_registrar.g.dart`, en vez de instanciar el adapter a mano — DRY y consistente con el codigo committeado), `await Hive.openBox<LevelProgressHiveModel>('level_progress')` (mismo nombre de box que consume `HiveLocalDataSource`), y `runApp(const ProviderScope(child: ArrowMazeApp()))`. `ArrowMazeApp` construye un `MaterialApp` con `initialRoute: AppRouter.home`, `onGenerateRoute: AppRouter.onGenerateRoute` y `debugShowCheckedModeBanner: false`.
- Desvio respecto al codigo literal del plan (justificado por el override aprobado por el usuario, UI 2026-06-17): en lugar de `theme: AppTheme.dark()` solo-dark, se wirean ambos temas `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()` y `themeMode: ThemeMode.system`, de modo que el SO selecciona claro u oscuro. Tambien se usa la extension `Hive.registerAdapters()` en lugar de `Hive.registerAdapter(LevelProgressHiveModelAdapter())`.
- Tests AAA: `test/widget_test.dart` reescrito (2): (1) `ArrowMazeApp` renderiza un `MaterialApp` cuyo `initialRoute` es `AppRouter.home`, con `onGenerateRoute` no nulo y banner de debug apagado; (2) expone `theme` (Brightness.light) y `darkTheme` (Brightness.dark) con `themeMode == ThemeMode.system`.
- TDD: GREEN. `flutter analyze`: No issues found! `flutter test`: 105/105 (el suite completo, +1 test nuevo en widget_test).
**Modificaciones realizadas por el equipo:**

---

## Entrada 019 — Pre-flight: prevenir solapamiento de flechas al colocarlas

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Antes del sprint de flechas dobladas, consolidar como fragmento propio la prevencion de solapamiento que estaba en el arbol sin commitear (dependencia del plan). `ArrowBoard.overlaps(arrow)` reporta si alguna celda del cuerpo de la flecha coincide con una celda ya ocupada por otra flecha; el generador solo coloca una candidata si `!overlaps && canExit`, de modo que dos flechas nunca comparten celdas.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) — orquestador subagent-driven
**Prompt o instruccion proporcionada:** > "PRE-FLIGHT: commitea como fragmento propio arrow_board.dart + graph_board_generator.dart (overlaps), dependencia del plan de flechas dobladas; deja home_screen.dart fuera."
**Resultado obtenido:**
- `lib/domain/arrows/entities/arrow_board.dart`: nuevo metodo `bool overlaps(Arrow arrow)` que usa `_occupiedExcluding(arrow.id)` y comprueba `arrow.cells.any(occupied.contains)`. Dominio Dart puro, opera sobre `cells` (agnostico a la forma de la flecha).
- `lib/infrastructure/generators/graph_board_generator.dart`: el bucle de colocacion pasa de `if (tempBoard.canExit(candidate.id))` a `if (!tempBoard.overlaps(candidate) && tempBoard.canExit(candidate.id))`, preservando la solubilidad por construccion (DAG) y anadiendo la garantia de no-solapamiento entre flechas.
- Verificacion: `flutter analyze` limpio y `flutter test` verde (refuerza una invariante existente; sin cambios de tests).
**Modificaciones realizadas por el equipo:**

## Entrada 020 — Task 1: Arrow como camino (cells + headDirection), Arrow.straight, retiro de ArrowLength

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Generalizar la entidad `Arrow` de "recta" (`tail` + `direction` + `length: ArrowLength`) a un modelo de CAMINO (`List<Position> cells` cola->cabeza + `Direction headDirection`); una flecha recta queda como caso degenerado. Retirar el VO `ArrowLength` (la longitud es `cells.length`). Mantener compatibles a los consumidores con getters `head/tail/direction/length` y una fabrica `Arrow.straight`.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando subagentes (implementador sonnet + QA arrowmaze-qa sonnet)
**Prompt o instruccion proporcionada:** > "Task 1 del plan flechas-dobladas: reescribe Arrow al modelo de camino, anade Arrow.straight + exitPath, elimina ArrowLength; QA migra todos los call sites y reescribe arrow_test con caminos doblados. flutter analyze 0 issues, flutter test verde."
**Resultado obtenido:**
- `lib/domain/arrows/entities/arrow.dart`: reescrito. `Arrow extends Equatable` con `{ArrowId id, List<Position> cells, Direction headDirection}` (const ctor). Getters de compat `head=cells.last`, `tail=cells.first`, `direction=headDirection`, `length=cells.length`. `factory Arrow.straight({id, tail, direction, length:int})` genera las celdas por direccion. `exitPath(cols, rows)` devuelve el rayo recto desde la cabeza en `headDirection` hasta el borde (vacio en el borde). Dominio Dart puro.
- `lib/domain/arrows/value_objects/arrow_length.dart`: eliminado (git rm); tambien su test `test/domain/value_objects/arrow_length_test.dart`.
- `lib/infrastructure/generators/graph_board_generator.dart`: construye la candidata con `Arrow.straight(...)` (interino recto; la generacion doblada llega en Task 3); sin import de `arrow_length.dart`.
- Migracion mecanica de tests: 10 archivos reemplazan `Arrow(id, tail, direction, length: ArrowLength(n))` por `Arrow.straight(...)` y `a.length.value` por `a.length`.
- Tests de dominio: `test/domain/entities/arrow_test.dart` reescrito (AAA, 23 casos) cubriendo caminos doblados ademas de rectos: `cells` cola->cabeza, `head/tail/length/direction`, `exitPath` en las 4 direcciones y su vaciado en el borde, una CURVA justo en la cabeza (verifica que `exitPath` sigue `headDirection`, no el ultimo segmento), e igualdad por Equatable de `Arrow.straight` vs un camino recto explicito.
- Verificacion (orquestador, independiente): `flutter analyze` -> No issues found!; `flutter test` -> 150/150 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 021 — Task 2: ArrowPainter orienta la punta por headDirection

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Que la punta triangular apunte segun `headDirection` (direccion por la que la cabeza sale) en lugar de derivarla del ultimo segmento del cuerpo. Asi, si el cuerpo gira justo en la cabeza, la punta sigue apuntando hacia donde la flecha sale.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando subagentes (implementador sonnet + QA arrowmaze-qa sonnet)
**Prompt o instruccion proporcionada:** > "Task 2: ArrowPainter recibe headDirection y orienta la punta por esa direccion; ArrowWidget la propaga; QA actualiza el test del painter con un caso de curva en la cabeza. flutter analyze 0 issues, flutter test verde."
**Resultado obtenido:**
- `lib/presentation/game/painters/arrow_painter.dart`: nuevo campo requerido `Direction headDirection` e import del VO. `_drawHead` calcula el angulo de la punta con un `switch (headDirection)` (right=0, left=pi, down=pi/2, up=-pi/2) en vez de `atan2` del ultimo segmento. `shouldRepaint` incluye `|| old.headDirection != headDirection`.
- `lib/presentation/game/widgets/arrow_widget.dart`: propaga `headDirection: widget.arrow.headDirection` al `ArrowPainter`.
- `lib/presentation/game/widgets/exiting_arrow_widget.dart`: ajuste interino obligado — tambien construye `ArrowPainter`, asi que pasa `headDirection: arrow.headDirection` para que `lib/` compile (este widget se reescribe por completo en Task 5).
- Tests: `test/presentation/game/painters/arrow_painter_test.dart` migrado a pasar `headDirection` y ampliado (AAA, +5 casos) con un grupo head-bend que prueba que la orientacion de la punta la gobierna `headDirection` y no el ultimo segmento (shouldRepaint independiente; divergencia de bytes de render up vs right; verificacion analitica del apex).
- Verificacion (orquestador, independiente): `flutter analyze` -> No issues found! (tras renombrar un local con guion bajo en el test que disparaba `no_leading_underscores_for_local_identifiers`); `flutter test` -> 155/155 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 022 — Task 3: Generacion de flechas dobladas (caminata auto-evitante) + maxPathLen en el puerto

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Hacer que el generador produzca flechas DOBLADAS (caminos serpenteantes auto-evitantes) en lugar de rectas, y propagar un parametro `maxPathLen` por el puerto `ILevelGenerator.generate`. Conservar intacta la solubilidad por construccion (gate `!overlaps && canExit`), el determinismo por seed y la degradacion con gracia.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando subagentes (implementador sonnet + QA arrowmaze-qa sonnet, con una iteracion de correccion de QA)
**Prompt o instruccion proporcionada:** > "Task 3: anade required maxPathLen al puerto, reescribe el generador con _randomBentArrow (caminata auto-evitante cabeza-primero con carril reservado); QA cubre determinismo, sin solapes, cuerpos validos, carril libre al colocar, solubilidad por orden inverso y degradacion. Regenera mocks con build_runner."
**Resultado obtenido:**
- `lib/domain/arrows/services/i_level_generator.dart`: `generate({required cols, rows, arrowCount, maxPathLen, int? seed})` — nuevo parametro requerido `maxPathLen`.
- `lib/infrastructure/generators/graph_board_generator.dart`: `_randomArrow` (recto) reemplazado por `_randomBentArrow` + helpers `_lane`, `_randomHeadWithClearLane`, `_freeNeighbors`. Elige cabeza+direccion con carril de salida libre, reserva ese carril, y crece el cuerpo HACIA ATRAS con una caminata aleatoria auto-evitante (2..maxPathLen). El gate de colocacion `if (!tempBoard.overlaps(candidate) && tempBoard.canExit(candidate.id))` queda VERBATIM sin cambios (preserva DAG, determinismo y degradacion con gracia via `_logger?.warn`).
- Acoplamiento minimo necesario (resuelve un hueco de orden del plan: el param requerido del puerto obliga a cablear el caller): `lib/application/state/game_controller.dart` pasa `maxPathLen: bp.maxPathLen`; `lib/domain/board/value_objects/level_blueprint.dart` gana el campo `maxPathLen` (valor placeholder, curva cuadrada antigua conservada). La curva vertical-densa real y la reescritura de su test llegan en Task 4.
- Mocks regenerados con `dart run build_runner build --delete-conflicting-outputs` (nueva firma del puerto): `game_controller_test.mocks.dart` y `board_widget_test.mocks.dart`.
- Tests (QA, AAA, logger mockeado): `i_level_generator_test.dart` (stub con maxPathLen, contrato), `graph_board_generator_test.dart` reescrito (determinismo por seed; sin solapes; cuerpos validos orto-adyacentes/sin repetir/en rango/`2<=length<=maxPathLen`; carril de cabeza libre frente a flechas ANTERIORES; solubilidad removiendo en orden inverso; degradacion con gracia). Una correccion de QA reemplazo un test erroneo que exigia el carril libre frente a TODAS las flechas (no es invariante: una flecha posterior puede ocupar el carril de una anterior; la solubilidad es por remocion en orden inverso) por el invariante correcto (carril libre frente a flechas de indice menor). Fakes `_SingleArrowGenerator`/`_EmptyBoardGenerator` actualizados con `maxPathLen`.
- Verificacion (orquestador, independiente): `flutter analyze` -> No issues found!; `flutter test` -> 160/160 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 023 — Task 4: Curva vertical-densa de LevelBlueprint

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Instalar la curva de dificultad vertical-densa real en `LevelBlueprint.forLevel` (el campo `maxPathLen` y el cableado en `GameController` ya se anadieron en Task 3 como acoplamiento minimo). El tablero crece de ~6x8 a ~11x15, mas alto que ancho, relleno ~68% con caminos cuyo largo maximo crece de 3 a 12.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando subagentes (implementador sonnet + QA arrowmaze-qa sonnet)
**Prompt o instruccion proporcionada:** > "Task 4: reemplaza forLevel por la curva vertical-densa (width/height/maxPathLen/arrowCount con clamps); QA reescribe level_blueprint_test verificando nivel 1 = 6x8 maxPathLen 3, verticalidad, clamps superiores, arrowCount en rango y monotonia. flutter test verde."
**Resultado obtenido:**
- `lib/domain/board/value_objects/level_blueprint.dart`: `forLevel` reescrito con la curva vertical-densa: `width=(6+(lvl-1)~/3).clamp(6,11)`, `height=(8+(lvl-1)~/2).clamp(8,15)`, `maxPathLen=(3+(lvl-1)~/2).clamp(3,12)`, `avgPathLen=(2+maxPathLen)/2`, `arrowCount=(width*height*0.68/avgPathLen).round().clamp(4, width*height)`. El campo `maxPathLen` y el ctor ya existian (Task 3).
- `lib/application/state/game_controller.dart`: sin cambios — `maxPathLen: bp.maxPathLen` ya estaba cableado desde Task 3.
- Tests: `test/domain/board/value_objects/level_blueprint_test.dart` reescrito (AAA, 16 casos en 7 grupos) verificando nivel 1 = 6x8 con maxPathLen 3; verticalidad (`rows>=cols`) en toda la muestra de niveles; clamps superiores (niveles altos -> 11x15, maxPathLen 12); `arrowCount` en `[4, width*height]`; y monotonia no decreciente de width/height/maxPathLen. (Se retiro un helper `expected` sin usar que disparaba `unused_element`.)
- Verificacion (orquestador, independiente): `flutter analyze` -> No issues found!; `flutter test` -> 172/172 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 024 — Task 5: Salida serpiente (SnakeExitPainter + reescritura de ExitingArrowWidget)

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Sustituir la animacion de salida (traslacion rigida) por una retraccion "serpiente" real: la cabeza sale primero y el cuerpo se retrae siguiendo su propio camino + el carril de salida. Es la pieza realmente nueva del sprint.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando subagentes (implementador sonnet + QA arrowmaze-qa sonnet)
**Prompt o instruccion proporcionada:** > "Task 5: crea SnakeExitPainter (retraccion cabeza-primero por la trayectoria cuerpo+carril), reescribe ExitingArrowWidget (sin travel, con cols/rows, progress via SnakeExitPainter, colapsa a SizedBox.shrink al terminar), y BoardWidget pasa cols/rows. QA reescribe el widget test y anade un test de unidad del painter."
**Resultado obtenido:**
- `lib/presentation/game/painters/snake_exit_painter.dart`: CREADO. Construye la trayectoria = centros del cuerpo (cola->cabeza) ++ carril recto mas alla del borde; a `progress` t desplaza cada vertice del cuerpo una distancia de arco `t*(bodyArc+laneArc)`, de modo que la cabeza cruza primero y la cola la sigue. Dibuja glow + cuerpo grueso + punta orientada por la direccion. `shouldRepaint` compara progress/cells/color/cell.
- `lib/presentation/game/widgets/exiting_arrow_widget.dart`: REESCRITO. Nueva firma `{arrow, minCol, minRow, cols, rows, cell, color, nonce}` (sin `travel`/`onComplete`); `AnimationController` 360ms; `AnimatedBuilder` pinta `SnakeExitPainter(progress: Curves.easeIn(t))` y colapsa a `SizedBox.shrink()` al completarse. Keyed por `exitNonce` para re-animar cada salida.
- `lib/presentation/game/widgets/board_widget.dart`: el overlay llama `_positionExiting(state.exitingArrow!, cell, state.exitNonce, board.cols, board.rows)` y `_positionExiting` propaga `cols`/`rows` al `ExitingArrowWidget` (se quita el viejo `travel = math.max(width,height)`; se conserva `dart:math as math` para `math.min` del tamano de celda). El `Stack` con `Clip.none` se mantiene para que la flecha cruce el borde sin recortarse.
- Tests (QA, AAA, flutter_test): `exiting_arrow_widget_test.dart` reescrito (5 casos: monta con flecha doblada y pinta `CustomPaint` con `SnakeExitPainter`; `progress` creciente al avanzar la animacion; colapsa a `SizedBox.shrink` al completar; migracion de firma). `snake_exit_painter_test.dart` creado (7 casos: no-throw en varias direcciones/curvas; `shouldRepaint` true al cambiar `progress`).
- Verificacion (orquestador, independiente): `flutter analyze` -> No issues found!; `flutter test` -> 181/181 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 025 — Cierre del sprint: flechas dobladas, tablero vertical denso y salida serpiente

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Cierre del sprint (Task 6): documentar el comportamiento publico nuevo en `README.md` y registrar el resumen del sprint. Referencia: spec `docs/superpowers/specs/2026-06-20-flechas-dobladas-tablero-vertical-design.md` y plan `docs/superpowers/plans/2026-06-20-flechas-dobladas-tablero-vertical.md`.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando subagentes (subagent-driven-development)
**Prompt o instruccion proporcionada:** > "Task 6: actualiza el README (flechas que doblan = modelo de camino Arrow cells+headDirection; tablero vertical denso = curva LevelBlueprint.forLevel; salida serpiente cabeza-primero, solubilidad por construccion intacta) y anade la entrada de cierre del sprint."
**Resultado obtenido:**
- `README.md`: seccion "Game Mechanic" reescrita para reflejar el comportamiento publico nuevo: flechas como CAMINO (`Arrow.cells` + `headDirection`) que doblan; condicion de salida = carril recto desde la cabeza; salida "serpiente" (cabeza primero, el cuerpo se retrae por su propio camino, `SnakeExitPainter`); solubilidad por construccion (remocion en orden inverso) y dificultad concentrada en `LevelBlueprint.forLevel`. La descripcion menciona el tablero vertical denso de flechas serpenteantes.
- Resumen del sprint (Tasks 1-6): (1) `Arrow` pasa de recta a camino + `Arrow.straight`, retiro de `ArrowLength`; (2) `ArrowPainter` orienta la punta por `headDirection`; (3) generador de flechas dobladas (caminata auto-evitante) + `maxPathLen` en el puerto; (4) curva vertical-densa de `LevelBlueprint`; (5) salida serpiente (`SnakeExitPainter` + reescritura de `ExitingArrowWidget`); (6) documentacion. Render y hit-testing ya eran agnosticos a la forma; la solubilidad por construccion (DAG), el determinismo por seed y el undo se conservan.
- Verificacion final (orquestador, independiente): `flutter analyze` -> No issues found!; `flutter test` -> 181/181 verde.
**Modificaciones realizadas por el equipo:**

## Entrada 026 — Fix de revision final: guard de precondicion maxPathLen >= 2 en el puerto

**Fecha:** 2026-06-20
**Tarea o problema abordado:** Unico fix exigido por la revision final de rama (READY-WITH-FIXES): el puerto publico `ILevelGenerator.generate` declaraba `required int maxPathLen` sin cota inferior, pero el generador (`targetLen = 2 + rng.nextInt(maxPathLen - 1)`) lanza `RangeError` si `maxPathLen < 2`. Riesgo latente (todos los callers actuales pasan por `LevelBlueprint.forLevel`, clamp >= 3), pero es superficie de contrato publico (ISP/LSP).
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) orquestando un subagente de fix (sonnet, disciplina arrowmaze-qa para el test)
**Prompt o instruccion proporcionada:** > "Revision final READY-WITH-FIXES: anade assert(maxPathLen>=2) en generate(), documenta la precondicion en el puerto y un test AAA que verifica que maxPathLen:1 lanza AssertionError."
**Resultado obtenido:**
- `lib/infrastructure/generators/graph_board_generator.dart`: `assert(maxPathLen >= 2, 'maxPathLen must be >= 2; got $maxPathLen');` como primera sentencia de `generate()` (consistente con el `assert(length >= 1)` de `Arrow.straight`).
- `lib/domain/arrows/services/i_level_generator.dart`: la doc del puerto documenta la precondicion `maxPathLen >= 2`.
- `test/infrastructure/generators/graph_board_generator_test.dart`: nuevo caso AAA que verifica que `generate(..., maxPathLen: 1)` lanza `AssertionError`. El caso `maxPathLen=2` existente no se afecta (2 >= 2 pasa el guard).
- Verificacion (orquestador, independiente): `flutter analyze` -> No issues found!; `flutter test` -> 182/182 verde.
**Modificaciones realizadas por el equipo:**
  
 ## Entrada 027 — front#14: Token storage seguro + auto-login (E3.3 / E3.6 parcial)

**Fecha:** 2026-07-08
**Tarea o problema abordado:** Implementar el almacenamiento seguro del token JWT y la auto-restauración de sesión al iniciar (auto-login sin re-login), issue `front#14` del reparto (`docs/superpowers/plans/2026-06-23-critical-path-and-team-split.md`). Contrato de cable congelado por `back#2` (ya mergeado): `POST /auth/login` y `/auth/register` devuelven `{ token: string }`, JWT con `expiresIn: 7d` y payload `{ sub, email }`. La UI de login/registro, el interceptor Dio y el guard de ruta son `front#15` (fuera de alcance).
**Herramienta de IA utilizada:** Claude Code (Opus 4.8) — TDD estricto (RED→GREEN verificado).
**Prompt o instruccion proporcionada:** > "soy isaac, quiero seguir con la siguiente tarea front#14 (token storage + auto-login) asignada en ArrowMaze/docs/superpowers/plans/2026-06-23-critical-path-and-team-split.md"
**Resultado obtenido:**
- **Decisiones (aprobadas por el usuario):** (1) almacenamiento con `flutter_secure_storage` (Keychain iOS / EncryptedSharedPreferences+Keystore Android) — dependencia nueva `flutter_secure_storage: ^9.2.2`; (2) rama `feat/#14-token-storage` a partir de `feat/main-sprint` (main aún sin baseline del Paso 0).
- **Domain (Dart puro):** `domain/auth/value_objects/auth_token.dart` — VO `AuthToken` (Equatable) que valida token no-vacío y decodifica el claim `exp` del JWT para `isExpired({DateTime? now})`; ante token opaco/sin `exp`/payload corrupto devuelve `false` (no bloquea: el server valida la firma). `domain/auth/repositories/i_auth_token_storage.dart` — puerto `IAuthTokenStorage { save/read/clear }` (ISP + DIP).
- **Infrastructure:** `infrastructure/data_sources/local/secure_token_data_source.dart` — `SecureTokenDataSource` (wrapper delgado sobre `FlutterSecureStorage`, seam no testeable, patrón Petros como `HiveLocalDataSource`). `infrastructure/repositories/secure_auth_token_repository.dart` — `SecureAuthTokenRepository implements IAuthTokenStorage`, mapea `AuthToken`↔`String` vía el DataSource (Adapter; nunca toca el plugin directamente).
- **Application:** `application/state/auth_state.dart` — `sealed AuthState` con `Authenticated(AuthToken)` / `Unauthenticated` (State pattern, consumido por el guard de front#15). `application/use_cases/restore_session_use_case.dart` — `RestoreSessionUseCase` (auto-login: lee storage; si no hay token → `Unauthenticated`; si expiró → `clear()` + `Unauthenticated`; si válido → `Authenticated`). `application/state/auth_controller.dart` — `AuthController extends AsyncNotifier<AuthState>` cuyo `build()` = restaurar sesión, más `saveSession(token)` (lo llamará front#15 tras login) y `signOut()`. `authControllerProvider` con fábrica-que-lanza por defecto (mismo patrón que `gameControllerProvider`), sobreescrita en el composition root.
- **Wiring (composition root):** `lib/main.dart` compone `SecureAuthTokenRepository(SecureTokenDataSource(const FlutterSecureStorage()))` e inyecta el `AuthController` vía `authControllerProvider.overrideWith(...)` en el `ProviderScope`. El `build()`/auto-login se dispara cuando el guard de ruta (front#15) lea el provider por primera vez.
- **Tests AAA (22 nuevos):** `auth_token_test.dart` (9: validación + expiración con JWT de juguete y reloj inyectado), `secure_auth_token_repository_test.dart` (5, `SecureTokenDataSource` mockeado — incluye string vacío→null), `restore_session_use_case_test.dart` (4, `IAuthTokenStorage` mockeado — válido/ausente/expirado+clear), `auth_controller_test.dart` (4, `ProviderContainer` con override — build restaura, saveSession, signOut). Mocks vía `build_runner`/mockito.
- **TDD:** RED→GREEN verificado en cada ciclo (AuthToken aislado sin mocks; resto con stubs `UnimplementedError` → impl). `flutter analyze`: No issues found! `flutter test`: **127/127** (105 previos + 22 nuevos, sin regresiones).


## Entrada 028 — fix: eliminar imports sin uso en main.dart (desbloquea CI del PR #27)

**Fecha:** 2026-07-09
**Tarea o problema abordado:** El PR #27 (`ci/#7-flutter-checks`, que añade el workflow de `flutter analyze` + `flutter test` en cada PR) no podía mergearse: el propio check de `flutter analyze` fallaba con exit code 1 por 4 warnings `unused_import` en `lib/main.dart` (líneas 12-15: `command_invoker.dart`, `game_controller.dart`, `remove_arrow_use_case.dart`, `graph_board_generator.dart`). Eran restos del wiring manual de GameController previo a que el provider asumiera su propia composición; el composition root ya no los referencia.
**Herramienta de IA utilizada:** Claude Code (Fable 5)
**Prompt o instrucción proporcionada:** > "Ayudame a resolver el pull request del front que esta pendiente. Las pruebas salen con error por lo que no se puede hacer el merge (no quiero quitar la regla de que los pull request deben tener bien las pruebas)."
**Resultado obtenido:** Se eliminaron los 4 imports sin uso de `lib/main.dart`. Sin cambios de comportamiento ni de funcionalidad pública (no aplica actualización de README ni tests nuevos: es limpieza de imports detectada por el linter). Verificación local en la rama del PR: `flutter analyze` → No issues found!; `flutter test` → 208/208 en verde.
**Modificaciones realizadas por el equipo:**

## Entrada 029 — Triage front#32: especificación completa del hint de auto-resolución

**Fecha:** 2026-07-09
**Tarea o problema abordado:** front#32 estaba en `needs-triage` con decisiones abiertas (modo del hint vs partida en curso, elegibilidad, trigger UX, dependencias). Sesión de triage + grilling con el maintainer para dejarlo `ready-for-agent`.
**Herramienta de IA utilizada:** Claude Code (Fable 5) — /triage + /grilling + /domain-modeling
**Prompt o instrucción proporcionada:** > "Repasemos y editemos los 2 últimos issues creados (1 front y uno back), para especificarlos por completo y estén listos para un agente. Toma docs/adr/0002-backend-owns-canonical-solution.md"
**Resultado obtenido:** Decisiones de diseño (sin código): el hint **reinicia el nivel** y reproduce la Solución canónica completa como demo no puntuada (sin CommandInvoker/MoveCount/StrikeCount/GameWon/progreso; input y undo bloqueados); al terminar, auto-reinicio a tablero jugable. Elegibilidad = política de dominio del cliente (`HintPolicy`, nivel ≥ 7, constante ajustable) — el server no gatea. Trigger: IconButton bombilla en el AppBar junto al undo. Bloqueado por back#19, front#8 y front#9 (sin niveles del server, los ArrowId no corresponden al tablero local). Cuerpo del issue reescrito como Agent Brief; glosario `CONTEXT.md` ampliado con **Solution** y **Hint**.
**Modificaciones realizadas por el equipo:** (completar manualmente)
## Entrada 029 — Password VO

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 1 de `front#15` (login/registro UI): crear el Value Object `Password` en `domain/auth/value_objects/`, primera pieza del formulario de registro/login. Encapsula la política mínima de longitud (≥8 caracteres, alineada con la validación del back) como regla de dominio reutilizable en lugar de esparcir el número mágico "8" por formularios y use cases.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/domain/auth/value_objects/password.dart` — clase `Password extends Equatable` (mismo patrón que la `Email` VO hermana) con `static const int minLength = 8` y constructor que lanza `ArgumentError` si `value.length < minLength`. `test/domain/auth/password_test.dart` — 4 casos AAA: acepta 8 caracteres, rechaza 7 caracteres, rechaza vacío, igualdad por valor (Equatable). TDD estricto: RED confirmado (`Password` no definido / target of URI doesn't exist) → GREEN confirmado (4/4 tests en verde) tras la implementación mínima. Sin dependencias de otras tareas del feature; VO autocontenido, Dart puro sin imports de Flutter.
**Modificaciones realizadas por el equipo:**

## Entrada 030 — AuthFailure sellado

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 2 de `front#15` (login/registro UI): crear la jerarquía sellada `AuthFailure` en `domain/auth/failures/`, para que la UI de login/registro (tareas posteriores del mismo feature) haga pattern matching exhaustivo sobre los fallos esperados del flujo de autenticación y muestre un mensaje en español sin conocer detalles de red/HTTP.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/domain/auth/failures/auth_failure.dart` — `sealed class AuthFailure { const AuthFailure(); String get message; }` con cuatro subclases `const`: `InvalidCredentials` ("Email o contraseña incorrectos"), `EmailAlreadyRegistered` ("Ese email ya está registrado"), `NetworkFailure` ("Sin conexión. Intenta de nuevo") y `UnexpectedFailure` ("Algo salió mal. Intenta más tarde"). `test/domain/auth/auth_failure_test.dart` — 2 casos AAA: los cuatro mensajes exactos y que las subclases son `AuthFailure`. TDD estricto: RED confirmado (tipos no definidos) → GREEN confirmado (2/2 tests en verde) tras la implementación mínima. Dart puro sin imports de Flutter ni dependencias de otras tareas del feature. Verificación completa: `flutter analyze` → No issues found!; `flutter test` → 219/219 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 031 — IAuthRepository + LoginUseCase

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 3 de `front#15` (login/registro UI): crear el puerto `IAuthRepository` en `domain/auth/repositories/` y el caso de uso `LoginUseCase` en `application/use_cases/`, que conecta la futura pantalla de login con la infraestructura de red (Dio, tarea posterior del mismo feature) sin que el dominio conozca detalles HTTP.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/domain/auth/repositories/i_auth_repository.dart` — `abstract interface class IAuthRepository { Future<Either<AuthFailure, AuthToken>> login(Email email, String password); Future<Either<AuthFailure, AuthToken>> register(Email email, String password); }` (puerto DIP, sin test por ser interfaz pura). `lib/application/use_cases/login_use_case.dart` — `LoginUseCase(IAuthRepository repo)` con `execute(String email, String password)`: construye el VO `Email` (capturando `ArgumentError` de formato inválido y devolviendo `Left(InvalidCredentials())` sin llegar a golpear el repo) y delega en `repo.login(...)`, propagando su `Either` sin transformarlo. `test/application/use_cases/login_use_case_test.dart` — 3 casos AAA con `MockIAuthRepository` (mockito/`@GenerateMocks`): delega con Email válido y retorna el `Right` del repo (verificado con `captureAny`), reenvía un `Left` del repo sin alterarlo, y corta en corto devolviendo `Left(InvalidCredentials())` sin invocar `repo.login` ante email malformado (`verifyNever`). TDD estricto: RED confirmado (`LoginUseCase` no definido) tras generar los mocks con `build_runner` → GREEN confirmado (3/3 tests en verde) tras la implementación mínima. Verificación completa: `flutter analyze` → No issues found!; `flutter test` → 222/222 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 032 — RegisterUseCase

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 4 de `front#15` (login/registro UI): crear el caso de uso `RegisterUseCase` en `application/use_cases/`, que conecta la futura pantalla de registro con `IAuthRepository.register` aplicando la política de contraseña (`Password` VO, ≥8) antes de tocar la red.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/application/use_cases/register_use_case.dart` — `RegisterUseCase(IAuthRepository repo)` con `execute(String email, String password)`: construye el VO `Email` y valida la contraseña con `Password(password)` (≥8) antes de golpear el repo; cualquier `ArgumentError` de cualquiera de los dos VOs (email malformado o password corto) se traduce a `Left(UnexpectedFailure())` sin invocar `repo.register`. Si ambos VOs son válidos, delega en `repo.register(emailVo, password)` propagando su `Either` sin transformarlo (el valor crudo del password viaja al repo; el back re-valida). `test/application/use_cases/register_use_case_test.dart` — 3 casos AAA con `MockIAuthRepository` (mockito/`@GenerateMocks`): delega con Email+Password válidos y retorna el `Right` del repo (verificado con `captureAny`), reenvía un `Left(EmailAlreadyRegistered())` del repo sin alterarlo, y corta en corto devolviendo `Left` sin invocar `repo.register` ante password de menos de 8 caracteres (`verifyNever`). TDD estricto: RED confirmado (`RegisterUseCase` no definido) tras generar los mocks con `build_runner` → GREEN confirmado (3/3 tests en verde) tras la implementación mínima. Verificación completa: `flutter analyze` → No issues found!; `flutter test` → 225/225 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 033 — Remote auth adapter

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 5 de `front#15` (login/registro UI): crear el data source `AuthRemoteDataSource` (Dio) en `infrastructure/data_sources/remote/` y el repositorio adaptador `RemoteAuthRepository` en `infrastructure/repositories/`, que implementa el puerto `IAuthRepository` traduciendo llamadas HTTP contra `/auth` del back al lenguaje del dominio (`AuthToken` / `AuthFailure`) sin que ninguna capa superior conozca Dio ni HTTP.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/infrastructure/data_sources/remote/auth_remote_data_source.dart` — `AuthRemoteDataSource(Dio dio)` con `login`/`register`: hacen `POST /auth/login` y `POST /auth/register` con `{email, password}` y devuelven `data['token']`; no mapean errores, propagan `DioException` tal cual (responsabilidad del repositorio adaptador). `lib/infrastructure/repositories/remote_auth_repository.dart` — `RemoteAuthRepository(AuthRemoteDataSource remote) implements IAuthRepository` (patrón Adapter: adapta el data source Dio al puerto de dominio): éxito → `Right(AuthToken(token))`; captura `DioException` y mapea 401→`InvalidCredentials` (login) / 400→`EmailAlreadyRegistered` (register), timeouts/`connectionError`→`NetworkFailure`, cualquier otro caso→`UnexpectedFailure`; error no-Dio → `UnexpectedFailure`. `test/infrastructure/data_sources/remote/auth_remote_data_source_test.dart` — 3 casos AAA con `MockDio` (mockito/`@GenerateMocks`): login hace POST y devuelve el token, register hace POST y devuelve el token, y una `DioException` en login se propaga sin capturar. `test/infrastructure/repositories/remote_auth_repository_test.dart` — 5 casos AAA con `MockAuthRemoteDataSource` (mockito/`@GenerateMocks`): login exitoso devuelve `Right(AuthToken)`, login con 401 mapea a `InvalidCredentials`, login con `connectionError` mapea a `NetworkFailure`, register con 400 mapea a `EmailAlreadyRegistered`, register con error no-Dio mapea a `UnexpectedFailure`. TDD estricto en ambos pares: RED confirmado (`AuthRemoteDataSource`/`RemoteAuthRepository` no definidos) tras generar los mocks con `build_runner` → GREEN confirmado (3/3 y 5/5 tests en verde respectivamente) tras la implementación mínima. Verificación completa: `flutter analyze` → No issues found!; `flutter test` → 233/233 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 034 — Dio client + token interceptor

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 6 de `front#15` (login/registro UI): crear `AppConfig` (URL base configurable por `--dart-define`), el `AuthTokenInterceptor` (AOP) y la factoría `DioClient` en `core/`, para que las llamadas HTTP de login/registro (y futuras, autenticadas) usen un único cliente Dio con la URL base correcta y el header `Authorization` inyectado automáticamente cuando hay sesión.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/core/config/app_config.dart` — `AppConfig.apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000')` (único punto de la URL base, SRP). `lib/core/network/auth_token_interceptor.dart` — `AuthTokenInterceptor(IAuthTokenStorage storage) extends Interceptor` (patrón AOP + Adapter): expone `attachToken(RequestOptions options)` extraído de `onRequest` para testear sin fabricar un `RequestInterceptorHandler`; lee el token con `storage.read()` y setea `Authorization: Bearer <token>` solo si hay sesión. `lib/core/network/dio_client.dart` — `DioClient.create(IAuthTokenStorage storage)` (factoría, único punto de construcción del `Dio`, SRP): fija `baseUrl: AppConfig.apiBaseUrl` con timeouts de 10s y engancha el `AuthTokenInterceptor`. `test/core/config/app_config_test.dart` — 1 caso: el default sin `--dart-define` es `http://10.0.2.2:3000`. `test/core/network/auth_token_interceptor_test.dart` — 2 casos AAA con `MockIAuthTokenStorage` (mockito/`@GenerateMocks`): añade el header cuando hay token, deja los headers intactos cuando no hay token. `test/core/network/dio_client_test.dart` — 1 caso: el `Dio` creado usa `AppConfig.apiBaseUrl` y registra exactamente un `AuthTokenInterceptor`. TDD estricto: RED confirmado (los tres archivos de producción no existían — errores de compilación "No such file or directory" / "isn't a type") tras generar los mocks con `build_runner` → GREEN confirmado (4/4 tests en verde) tras la implementación mínima. Verificación completa: `flutter analyze` sobre los 6 archivos nuevos → 1 warning preexistente en el test verbatim del brief (`unused_import` de `dio` en `dio_client_test.dart`, no se modifica por ser especificación literal de la tarea); `flutter test` (suite completa) → 237/237 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 035 — saveSession persist flag

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 7 de `front#15` (login/registro UI): extender `AuthController.saveSession` con un flag `persist` para soportar "recordarme" desmarcado — sesión solo en memoria, sin escribir en el almacenamiento (no habrá auto-login al reabrir la app).
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/application/state/auth_controller.dart` — `saveSession(AuthToken token, {bool persist = true})`: con `persist` `true` (default, compatible con front#14) escribe en `_storage.save(token)` antes de marcar `Authenticated`; con `persist` `false` marca `Authenticated` directamente sin tocar el storage. `test/application/state/auth_controller_test.dart` — 2 casos AAA nuevos dentro del `group('saveSession', ...)` existente: con `persist: false` transiciona a `Authenticated` y `verifyNever(mockStorage.save(any))`; con `persist: true` (explícito) hace `verify(mockStorage.save(token)).called(1)`. TDD estricto: RED confirmado (error de compilación "No named parameter with the name 'persist'") → GREEN confirmado (6/6 tests del archivo, incluyendo el caso preexistente de `saveSession`, `build` y `signOut`). Verificación completa: `flutter analyze` sobre los 2 archivos modificados → No issues found!; `flutter test` (suite completa) → 239/239 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 036 — AuthFormController + providers

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 8 de `front#15` (login/registro UI): crear `AuthFormState` (sealed: `FormIdle`/`FormSubmitting`/`FormError`) y `AuthFormController` en `application/state/`, la capa de orquestación que conecta `LoginUseCase`/`RegisterUseCase` con `AuthController.saveSession` según el flag "recordarme" de la UI.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/application/state/auth_form_state.dart` — `sealed class AuthFormState` (State pattern) con `FormIdle`, `FormSubmitting` y `FormError(AuthFailure failure)`, todas `const`, para que la UI haga pattern matching exhaustivo. `lib/application/state/auth_form_controller.dart` — providers `authRepositoryProvider` (`Provider<IAuthRepository>`, fábrica por defecto lanza `UnimplementedError` hasta sobrescribirse en `main`, mismo patrón DIP que `authControllerProvider`), `loginUseCaseProvider`, `registerUseCaseProvider` y `authFormControllerProvider` (`NotifierProvider<AuthFormController, AuthFormState>`); `AuthFormController extends Notifier<AuthFormState>` con `login`/`register(String email, String password, {required bool remember})`: fijan `FormSubmitting`, invocan el use case correspondiente y, en `Right`, delegan en `authControllerProvider.notifier.saveSession(token, persist: remember)` antes de volver a `FormIdle`; en `Left`, fijan `FormError(failure)`. `test/application/state/auth_form_controller_test.dart` — 4 casos AAA con `MockIAuthRepository`/`MockIAuthTokenStorage` (mockito/`@GenerateMocks`) y `ProviderContainer` sobrescribiendo `authRepositoryProvider` y `authControllerProvider` (con `AuthController` real + storage mockeado): login exitoso con `remember: true` persiste el token y termina en `FormIdle`; con `remember: false` autentica sin persistir (`verifyNever(storage.save(any))`); login fallido termina en `FormError` con el `AuthFailure` original; y se observa `FormSubmitting` sincrónicamente al iniciar el envío (antes de que resuelva el use case). TDD estricto: RED confirmado (errores de compilación — `auth_form_controller.dart` no existía, `authRepositoryProvider`/`authFormControllerProvider` indefinidos) tras generar los mocks con `build_runner` → GREEN confirmado (4/4 tests en verde) tras la implementación mínima. Verificación completa: `flutter analyze` → No issues found!; `flutter test` (suite completa) → 243/243 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 037 — AuthStrings + AuthTextField

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 9 de `front#15` (login/registro UI): crear `AuthStrings` (textos ES centralizados del flujo de auth) y el widget reusable `AuthTextField` en `presentation/auth/`, el primer input de la app con estética glassmorphism, base para `LoginScreen`/`RegisterScreen`.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/presentation/auth/auth_strings.dart` — `class AuthStrings` con constructor privado y `static const String` para títulos (`loginTitle`, `registerTitle`), labels (`emailLabel`, `passwordLabel`, `confirmPasswordLabel`), acciones (`rememberMe`, `forgotPassword`, `loginButton`, `registerButton`, `goToRegister`, `goToLogin`) y mensajes de validación (`emailInvalid`, `passwordTooShort`, `passwordEmpty`, `confirmMismatch`); único lugar de literales para que front#4 (i18n) los externalice a `.arb` sin cazar strings por las pantallas. `lib/presentation/auth/widgets/auth_text_field.dart` — `AuthTextField extends StatelessWidget` con `{required TextEditingController controller, required String label, bool obscureText = false, TextInputType keyboardType = TextInputType.text, String? errorText, ValueChanged<String>? onChanged}`: envuelve un `TextField` con estilo glassmorphism sensible a `Theme.of(context).brightness`, leyendo `AppColors.glassFill`/`glassBorder`/`onBackground`/`onSurfaceMuted` (o su contraparte `light*`) y bordes redondeados con `AppColors.primary`/`error` en foco/error, espejando el idiom de `level_selection_screen.dart`. `test/presentation/auth/widgets/auth_text_field_test.dart` — 3 casos con `testWidgets` dentro de `MaterialApp(home: Scaffold(...))`: muestra el label y reenvía el texto tecleado al controller, renderiza el `errorText` provisto, y oculta el texto cuando `obscureText` es `true`. TDD estricto: RED confirmado (`auth_text_field.dart` no existía — "No such file or directory" / `AuthTextField` método no encontrado) → GREEN confirmado (3/3 tests en verde) tras la implementación mínima. Verificación completa: `flutter analyze` → No issues found!; `flutter test` (suite completa) → 247/247 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 038 — LoginScreen

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 10 de `front#15` (login/registro UI): crear `LoginScreen` en `presentation/auth/screens/`, la pantalla de inicio de sesión que conecta `AuthTextField`/`AuthStrings` (Task 9) con `authFormControllerProvider` (Task 8): valida en cliente (Email VO + password no vacío), envía el formulario y refleja `FormSubmitting`/`FormError` en la UI sin navegar ella misma tras el éxito.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/presentation/auth/screens/login_screen.dart` — `LoginScreen extends ConsumerStatefulWidget` (const): dos `AuthTextField` (email/password), checkbox "recordarme" (default `true`), `TextButton` "olvidé contraseña" deshabilitado (`onPressed: null`, placeholder sin endpoint de reset en el back), `FilledButton` de envío y un `TextButton` "¿No tienes cuenta?" que navega a `RegisterScreen` vía `Navigator.push(MaterialPageRoute(...))`. `_validate()` construye el VO `Email` en un try/catch (`ArgumentError` → `AuthStrings.emailInvalid`) y chequea password no vacío (`AuthStrings.passwordEmpty`) antes de invocar `authFormControllerProvider.notifier.login(email, password, remember:)`. `ref.watch(authFormControllerProvider)` deshabilita el botón de envío y muestra un spinner en `FormSubmitting`, y el mensaje de `failure.message` en `FormError`; no navega en éxito (el `AuthGate` de la Task 12 resuelve la transición). Se creó además un placeholder temporal `lib/presentation/auth/screens/register_screen.dart` (`RegisterScreen extends StatelessWidget`, `Scaffold()` vacío) únicamente para que el import de `LoginScreen` compile antes de la Task 11, que lo reemplazará con la pantalla completa. `test/presentation/auth/screens/login_screen_test.dart` — 3 `testWidgets` con `_StubFormController extends AuthFormController` (override de `build()` a un `AuthFormState` fijo) inyectado vía `authFormControllerProvider.overrideWith(...)`: envío con campos vacíos muestra `emailInvalid` + `passwordEmpty`; `FormSubmitting` deja el botón con `onPressed == null`; `FormError(InvalidCredentials())` muestra el mensaje del fallo. TDD estricto: RED confirmado (`login_screen.dart` no existía — "No such file or directory" / `LoginScreen` método no encontrado) → GREEN confirmado (3/3 tests en verde) tras la implementación mínima. Verificación completa: `flutter analyze` → No issues found!; `flutter test` (suite completa) → 250/250 en verde (sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 039 — RegisterScreen

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 11 de `front#15` (login/registro UI): reemplazar el placeholder temporal de la Task 10 con la pantalla completa `RegisterScreen` en `presentation/auth/screens/`, que añade confirmación de contraseña y la política de longitud mínima (`Password.minLength`) sobre la base de `LoginScreen`.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/presentation/auth/screens/register_screen.dart` — `RegisterScreen extends ConsumerStatefulWidget` (const), reemplazando por completo el stub `Scaffold()` vacío de la Task 10: tres `AuthTextField` (email/password/confirmar contraseña), checkbox "recordarme" (default `true`), `FilledButton` de envío y un `TextButton` "¿Ya tienes cuenta?" que hace `Navigator.of(context).pop()` (sin importar `LoginScreen`, ya que `LoginScreen` navega hacia esta pantalla con `push`, no con rutas nombradas). `_validate()` construye el VO `Email` en un try/catch (`ArgumentError` → `AuthStrings.emailInvalid`), chequea `password.length < Password.minLength` (→ `AuthStrings.passwordTooShort`) y compara `confirm != password` (→ `AuthStrings.confirmMismatch`) antes de invocar `authFormControllerProvider.notifier.register(email, password, remember:)`. `ref.watch(authFormControllerProvider)` deshabilita el botón de envío y muestra un spinner en `FormSubmitting`, y el mensaje de `failure.message` en `FormError`; no navega en éxito (el `AuthGate` resuelve la transición). `test/presentation/auth/screens/register_screen_test.dart` — 2 `testWidgets` con `_StubFormController extends AuthFormController` (override de `build()` a un `AuthFormState` fijo) inyectado vía `authFormControllerProvider.overrideWith(...)`: email válido + password corta + confirmación no coincidente muestra `passwordTooShort` + `confirmMismatch`; `FormSubmitting` deja el botón con `onPressed == null`. TDD estricto: RED confirmado (el stub de la Task 10 no tiene campos ni botón — "Bad state: No element" al buscar `TextField`/`FilledButton` por texto) → GREEN confirmado (2/2 tests en verde) tras sobrescribir el stub con la implementación completa. Verificación completa: `flutter analyze` → No issues found!; `flutter test` (suite completa) → 252/252 en verde (sin regresiones, incluyendo los 3 tests de `LoginScreen` que navega hacia esta pantalla).
**Modificaciones realizadas por el equipo:**

## Entrada 040 — AuthGate + wiring + README

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Task 12 (final) de `front#15` (login/registro UI): crear el guard de ruta `AuthGate` en `core/auth/`, componer el resto del lazo de auth en `main.dart` (Dio client + `RemoteAuthRepository` + override de `authRepositoryProvider`, y `home: AuthGate()` reemplazando `initialRoute`) y documentar el flujo en `README.md`. Es la pieza que pone en producción todo lo construido en las Tasks 1–11.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8)
**Prompt o instrucción proporcionada:** > "front#15 login/registro UI"
**Resultado obtenido:** `lib/core/auth/auth_gate.dart` — `AuthGate extends ConsumerWidget` (const, patrón Observer/State): `ref.watch(authControllerProvider).when(loading: → _Splash, error: → LoginScreen, data: (state) => switch (state) { Authenticated() => HomeScreen(), Unauthenticated() => LoginScreen() })`; vive en el `home` del `MaterialApp` porque la app usa Navigator 1.0 sin go_router. `lib/main.dart` — se añaden `dio = DioClient.create(tokenStorage)` y `authRepository = RemoteAuthRepository(AuthRemoteDataSource(dio))` tras `tokenStorage`; `authRepositoryProvider.overrideWithValue(authRepository)` se agrega a `overrides`; `initialRoute: AppRouter.home` se reemplaza por `home: const AuthGate()`, conservando `onGenerateRoute: AppRouter.onGenerateRoute` para que las rutas nombradas del juego sigan resolviéndose dentro del subtree autenticado. `test/core/auth/auth_gate_test.dart` — 2 `testWidgets` con `MockIAuthTokenStorage` (mockito/`@GenerateMocks`) y `AuthController`/`RestoreSessionUseCase` reales sobre el storage mockeado: storage sin token → `LoginScreen` (no `HomeScreen`); token JWT válido de larga duración (`exp` en 2100, literal verbatim del brief) → `HomeScreen`. En el segundo caso se reemplazó el `pumpAndSettle()` propuesto por pumps acotados (`pump()` + `pump(400ms)`), porque `HomeScreen` anima su logo en bucle infinito (`AnimationController..repeat()`) y nunca se asienta — mismo patrón ya usado en `test/presentation/home/home_screen_test.dart`. TDD estricto: RED confirmado (`AuthGate` no definido — "No such file or directory" / "Method not found") tras generar los mocks con `build_runner` → GREEN confirmado (2/2 tests en verde) tras la implementación mínima. Se actualizó además `test/widget_test.dart` (pre-existente), cuyo primer caso aserta `materialApp.initialRoute == AppRouter.home`, roto por este mismo cambio de wiring; se reemplazó por `materialApp.home is AuthGate` para reflejar el nuevo composition root. `README.md` — se añaden `LoginUseCase`/`RegisterUseCase` al árbol de `application/use_cases/`, `presentation/auth/` y `core/auth/auth_gate.dart` al árbol de arquitectura, una nota "Auth flow" (endpoints `/auth/login`·`/auth/register`, `--dart-define=API_BASE_URL`, default `http://10.0.2.2:3000`, persistencia del JWT y swap de `AuthGate`), y se extiende la fila **Adapter** de la tabla de Design Patterns para citar `remote_auth_repository.dart` y `auth_token_interceptor.dart`. Verificación completa tras el wiring: `flutter analyze` → No issues found!; `flutter test` (suite completa) → 254/254 en verde (sin regresiones; incluye la corrección de `widget_test.dart`).
**Modificaciones realizadas por el equipo:**

## Entrada 041 — Fix: registro deja al usuario en HomeScreen (pop de RegisterScreen al autenticarse)

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Bug Crítico detectado en la revisión final de rama de `front#15`: `LoginScreen` ES la ruta `"/"` (`AuthGate.build`), pero `RegisterScreen` se abre desde `LoginScreen` con `Navigator.push(MaterialPageRoute(...))`, es decir, se apila *encima* de `"/"`. Al registrarse con éxito, `AuthFormController.register` llama a `AuthController.saveSession`, que cambia `AuthState` a `Authenticated`; `AuthGate` reconstruye entonces `"/"` de `LoginScreen` a `HomeScreen` — pero la `RegisterScreen` apilada nunca se cierra, así que queda encima tapando `HomeScreen` y el usuario recién registrado se queda varado en el formulario congelado. El flujo de login no tiene este bug porque `LoginScreen` es la propia ruta `"/"`, no una pantalla apilada.
**Herramienta de IA utilizada:** Claude Code (Opus 4.8, subagente `general-purpose`)
**Prompt o instrucción proporcionada:** > "Aplicar los fixes de la revisión final de rama de front#15: 1 bug Crítico (con test de regresión) + 2 documentation touch-ups."
**Resultado obtenido:** `lib/presentation/auth/screens/register_screen.dart` — en `build()` se añade `ref.listen(authControllerProvider, (previous, next) { next.whenData((state) { if (state is Authenticated && Navigator.of(context).canPop()) Navigator.of(context).pop(); }); })`, con comentario inline explicando por qué `RegisterScreen` (apilada sobre el `AuthGate` en `"/"`) debe cerrarse a sí misma para revelar el `HomeScreen` que el `AuthGate` ya montó en la raíz; no se tocó `LoginScreen` ni `AuthGate`. `test/presentation/auth/screens/register_flow_test.dart` (nuevo) — test de integración `popping RegisterScreen after successful sign-up reveals HomeScreen` que monta el cableado real (`ProviderScope` con `authRepositoryProvider.overrideWithValue(mockRepo)` y `authControllerProvider.overrideWith(() => AuthController(mockStorage, RestoreSessionUseCase(mockStorage)))`, `MaterialApp(home: AuthGate(), onGenerateRoute: AppRouter.onGenerateRoute)`) en vez de aislar `RegisterScreen` con stubs: arranca en `LoginScreen` (storage sin token), navega a `RegisterScreen` vía el link "¿No tienes cuenta?", completa email/password/confirmación válidos, envía el formulario (`mockRepo.register` resuelve `Right(AuthToken(<JWT de larga duración, mismo literal `exp` en 2100 que `auth_gate_test.dart`>))`), bombea con pumps acotados (no `pumpAndSettle`, porque `HomeScreen` anima en bucle infinito) y asevera `find.byType(RegisterScreen), findsNothing` (aserción discriminante: presente en ambos estados buggy/fixed sería `find.byType(HomeScreen)` solo, que no distingue el bug) junto con `find.byType(HomeScreen), findsOneWidget`. `test/presentation/auth/screens/register_flow_test.mocks.dart` (nuevo, generado por `build_runner`) — mocks de `IAuthRepository`/`IAuthTokenStorage`. TDD estricto: RED confirmado genuinamente — con el código de la Task 11 (sin el listener) el test falla con `Expected: no matching candidates / Actual: Found 1 widget with type "RegisterScreen"`, reproduciendo el bug reportado — → GREEN confirmado (1/1 test en verde) tras añadir el listener, con pumps calibrados para atravesar la transición de pop (`pump()` ×3 para los saltos async de `register()`/`saveSession()`/`storage.save()`, luego `pump(300ms)` ×2 para la animación de pop de `MaterialPageRoute`). `lib/core/network/auth_token_interceptor.dart` — comentario inline añadido en `attachToken` documentando (sin cambiar lógica) que el interceptor lee el token de `IAuthTokenStorage` (persistente), así que una sesión con `remember: false` (en memoria vía `AuthState.Authenticated`, nunca escrita en el storage) enviará peticiones autenticadas SIN el header `Authorization`; front#16/#17 deberán leer el token desde `AuthController`/`AuthState` o persistirlo igualmente para este interceptor. `README.md` — se actualiza el conteo de tests desactualizado en "Running Tests" de 105 a 255 (conteo real tras `flutter test`, suite completa). Verificación completa: `flutter analyze` → No issues found!; `flutter test` (suite completa) → 255/255 en verde (254 previos + el nuevo test de regresión, sin regresiones).
**Modificaciones realizadas por el equipo:**

## Entrada 042 — Glosario: GeneratedBoard (Tablero generado) + triage del módulo "Generar nivel"

**Fecha:** 2026-07-09
**Tarea o problema abordado:** Grilling + triage del módulo "modo random" (handoff surgido del grilling de front#1): definir la feature "Generar nivel" — el jugador configura dimensiones, dificultad (densidad de flechas) y timer opcional, y la app genera localmente un tablero soluble por construcción, efímero — y triagear los issues resultantes. Decisiones del maintainer: no puntuado (precedente hint no puntuado de back#19/front#32) · sin persistencia · sin hint en v1 (ADR 0002 intacto: un tablero generado no es un nivel servido; opción futura documentada: testigo del generador) · dims libres 4–10 + preset de dificultad → densidad + maxPathLen · timer a elección del jugador, derivado de la dificultad · seed visible y reproducible dentro de una misma versión de la app · mecánica idéntica (5 strikes → GameLost) · entrada en Home → configurador → juego → post-partida con Otro tablero / Repetir / Cambiar parámetros. Delimitación con E1.5/front#9: "Generar nivel" no pasa por `loadLevel` ni tiene `LevelId`; el fallback procedural de la Strategy queda intacto.
**Herramienta de IA utilizada:** Claude Code (Fable 5, skills /triage + grilling + domain-modeling)
**Prompt o instrucción proporcionada:** > "/triage — leer HANDOFF-random-mode-triage.md, grilling del módulo 'modo random' y crear los issues según docs/agents/issue-tracker.md con las 7 preguntas mínimas resueltas"
**Resultado obtenido:** Issues front#36 (`feat(app): GenerateBoard use case + GeneratorConfig` — ready-for-agent, sin bloqueos) y front#37 (`feat(ui): "Generar nivel" screen` — ready-for-agent, blocked by #36 y #6), ambos con Agent Brief completo al estilo de front#32 (Context / Brief / Blocked by / Provenance). `CONTEXT.md` — nueva entrada **GeneratedBoard (Tablero generado)** en "Nivel y progreso": `ArrowBoard` creado localmente con parámetros del jugador, soluble por construcción, efímero (no es `Level`, no puntúa, no persiste `Progress`, no participa del `Leaderboard`), reproducible por (seed, parámetros) dentro de una misma versión; _Avoid_: nivel generado, nivel random, nivel de práctica, modo práctica, Candidato.
## Entrada 042 — front#18 — LevelProgress VO

**Fecha:** 2026-07-09
**Tarea o problema abordado:** front#18 — sync local progress with server. Primer fragmento: implementar el VO `LevelProgress` de dominio (capa pura Dart), que encapsula el progreso reconciliable de un nivel (completado + mejor score/estrellas). Espejo de los campos opcionales del endpoint `/progress` (back#8). Usa `int?` en vez de los VOs `Score`/`Stars` de front#12 (aún no mergeados) para mantener esta feature autocontenida.
**Herramienta de IA utilizada:** Claude Opus 4.8 (1M context) — ejecución de subagent TDD
**Prompt o instrucción proporcionada:** > "Implementar Task 1: LevelProgress value object — TDD (RED → GREEN → analyze + AI_HISTORY + commit)."
**Resultado obtenido:**
- `lib/domain/board/value_objects/level_progress.dart` (nuevo): VO `LevelProgress extends Equatable` con constructor `LevelProgress({required LevelId levelId, required bool completed, int? bestScore, int? bestStars})` y campos `levelId`, `completed`, `bestScore`, `bestStars`. Valida en runtime: `bestScore >= 0` e `bestStars in 1..3` (si no null), lanzando `ArgumentError` ante violación. Dominio puro, única dependencia externa `equatable`.
- `test/domain/board/value_objects/level_progress_test.dart` (nuevo): 5 tests AAA (patrón ARRANGE/ACT/ASSERT):
  1. `should_hold_fields_when_constructed_with_valid_values` — VO construida con todos los campos.
  2. `should_allow_null_score_and_stars_when_level_completed_without_score` — campos null permitidos.
  3. `should_be_value_equal_when_all_fields_match` — igualdad por `Equatable.props`.
  4. `should_throw_when_bestScore_is_negative` — validación en constructor.
  5. `should_throw_when_bestStars_out_of_range` — validación en constructor (rango 1..3).
- TDD estricto verificado:
  - **RED (Step 2):** `flutter test` antes de la implementación → "Error: Error when reading 'level_progress.dart': No such file or directory" + 6 errores de compilación.
  - **GREEN (Step 4):** `flutter test` tras la implementación → "All tests passed! (5/5)".
  - **Analyze (Step 5):** `flutter analyze lib/domain/board/value_objects/level_progress.dart` → "No issues found!" (0.1s).
**Modificaciones realizadas por el equipo:**

## Entrada 043 — front#18 — ProgressReconciler

**Fecha:** 2026-07-09
**Tarea o problema abordado:** front#18 — sync local progress with server. Segundo fragmento: implementar el servicio de dominio `ProgressReconciler` (capa pura Dart) que fusiona el progreso local y remoto aplicando la regla "best score wins, completed = OR": por nivel, completa si está completado en cualquiera de las dos fuentes; score/estrellas toman el máximo (tratando null como peor). Reproduce la regla de `SyncProgressUseCase` del back para poder reconciliar sin depender del orden de respuesta del server.
**Herramienta de IA utilizada:** Claude Haiku 4.5 (agente task-2)
**Prompt o instrucción proporcionada:** > "Implementar Task 2: ProgressReconciler domain service — TDD (RED → GREEN → analyze + AI_HISTORY + commit). Consumes: LevelProgress, LevelId. Produces: reconcile(local, remote) merging by levelId.value; completed = local || remote; bestScore/bestStars = máximo tratando null como peor."
**Resultado obtenido:**
- `lib/domain/board/services/progress_reconciler.dart` (nuevo): clase pura `ProgressReconciler` con método público `List<LevelProgress> reconcile(List<LevelProgress> local, List<LevelProgress> remote)` que:
  1. Indexa local por `levelId.value` en un mapa (`byId`).
  2. Itera remote; para cada nivel, si existe en local lo fusiona via `_merge()`, si no lo añade directamente.
  3. Retorna `byId.values.toList()`.
  - Método privado `_merge(LevelProgress a, LevelProgress b)` construye una nueva `LevelProgress` combinando: `levelId` de `a`, `completed` con OR lógico, scores/estrellas con `_maxNullable()`.
  - Método privado `_maxNullable(int? a, int? b)` retorna el máximo no-null (si uno es null retorna el otro; si ambos null retorna null; si ambos no-null retorna el máximo).
  - Dominio puro: única dependencia `level_progress.dart`; cero imports de Flutter/Hive/Dio/Riverpod.
- `test/domain/board/services/progress_reconciler_test.dart` (nuevo): 4 tests AAA en `group('reconcile')`:
  1. `should_keep_higher_score_when_both_sides_have_score` — local(score=800, stars=2) + remote(score=1200, stars=3) → merged(score=1200, stars=3).
  2. `should_prefer_non_null_score_when_one_side_is_null` — local(no score) + remote(score=500, stars=1) → merged(score=500, stars=1).
  3. `should_mark_completed_when_completed_on_either_side` — local(completed=false) + remote(completed=true) → merged(completed=true).
  4. `should_include_levels_present_on_only_one_side` — local=[lp('1')], remote=[lp('2')] → merged.length=2 (ambos niveles presentes).
  - Helper `lp(id, completed, {score, stars})` factory para tests (reduce boilerplate).
  - Helper `pick(list, id)` para acceso por `levelId.value` (lee como en la app real).
- TDD estricto verificado:
  - **RED (Step 2):** `flutter test test/domain/board/services/progress_reconciler_test.dart` → "Error: Error when reading 'progress_reconciler.dart': No such file or directory" + 3 errores de compilación (ProgressReconciler not a type).
  - **GREEN (Step 4):** `flutter test test/domain/board/services/progress_reconciler_test.dart` → "00:00 +4: All tests passed!" (4/4).
  - **Analyze (Step 5):** `flutter analyze lib/domain/board/services/progress_reconciler.dart` → "No issues found!" (0.1s).
**Modificaciones realizadas por el equipo:**

## Entrada 044 — front#18 — local progress getAll/upsertAll + Hive fields

**Fecha:** 2026-07-09
**Tarea o problema abordado:** front#18 — sync local progress with server. Tercer fragmento: extender el stack local (Hive model → DataSource → puerto → repositorio) para exponer todo el progreso persistido (con score/estrellas) y permitir escribirlo de vuelta ya reconciliado, sin tocar los métodos existentes (`getProgress/saveProgress/markCompleted/isCompleted`) — extensión aditiva (OCP/LSP).
**Herramienta de IA utilizada:** Claude Opus 4.8 (1M context) — ejecución de subagent TDD
**Prompt o instrucción proporcionada:** > "Implementar Task 3: extend the local progress repository (Hive model fields + getAll/upsertAll) — TDD (RED → GREEN → analyze + AI_HISTORY + commit). Consumes: LevelProgress (Task 1), LevelId."
**Resultado obtenido:**
- `lib/infrastructure/models/level_progress_hive_model.dart`: se añaden dos campos aditivos y nullable — `@HiveField(3) int? bestScore` y `@HiveField(4) int? bestStars` — y el constructor se amplía con `this.bestScore, this.bestStars` (opcionales). Retrocompatible: registros Hive viejos sin estos fields leen `null`.
- `lib/infrastructure/models/level_progress_hive_model.g.dart` (regenerado con `build_runner`): adapter incluye lectura/escritura de `bestScore`/`bestStars`.
- `lib/infrastructure/data_sources/local/hive_level_progress_data_source.dart`: se añaden `List<LevelProgressHiveModel> getAllProgress() => _box.values.toList();` y `Future<void> upsertProgress(String levelId, bool completed, int? bestScore, int? bestStars)` — actualiza el registro existente (preservando `moveCount`) o crea uno nuevo con `moveCount: 0` (el flujo de sync no transporta `moveCount`, solo completado + mejor score/estrellas).
- `lib/domain/board/repositories/i_level_progress_repository.dart`: se añade el import de `LevelProgress` y dos métodos nuevos al puerto — `Future<List<LevelProgress>> getAll()` y `Future<void> upsertAll(List<LevelProgress> progress)` — documentados inline como necesarios para reconciliar con el remoto (front#18). Los 4 métodos preexistentes quedan intactos.
- `lib/infrastructure/repositories/hive_progress_repository.dart`: implementa `getAll()` mapeando cada `LevelProgressHiveModel` del datasource a `LevelProgress(levelId: LevelId(m.levelId), completed: m.completed, bestScore: m.bestScore, bestStars: m.bestStars)`, y `upsertAll()` iterando la lista y delegando cada entrada a `_dataSource.upsertProgress(p.levelId.value, p.completed, p.bestScore, p.bestStars)`.
- `test/infrastructure/repositories/hive_progress_repository_test.dart`: se añaden dos grupos — `getAll` (`should_map_all_models_to_level_progress_when_present`, verifica el mapeo completo incluyendo `bestScore`/`bestStars` y el caso `null`) y `upsertAll` (`should_upsert_each_entry_when_saving_merged_progress`, verifica la delegación posicional al datasource vía `verify(mockDataSource.upsertProgress('1', true, 900, 3)).called(1)`).
- `test/infrastructure/repositories/hive_progress_repository_test.mocks.dart` (regenerado con `build_runner`): el mock de `HiveLocalDataSource` incluye ahora `getAllProgress()`/`upsertProgress(...)`.
- Efecto colateral necesario (no listado en el brief, pero mecánico): `test/domain/repositories/i_level_progress_repository_test.dart` contiene un fake en memoria (`_InMemoryLevelProgressRepository`) que implementa `ILevelProgressRepository` para verificar LSP del contrato. Al ampliar el puerto con `getAll`/`upsertAll`, ese fake dejaba de compilar (Dart exige implementar todos los miembros de una `abstract interface class`). Se añadió una implementación mínima en memoria (`Map<String, LevelProgress> _all`) para mantener el contrato compilable; no se modificó ningún método existente ni se alteraron los tests preexistentes de ese archivo.
- TDD estricto verificado:
  - **RED (Step 4):** `flutter test test/infrastructure/repositories/hive_progress_repository_test.dart` (tras Steps 1-3, antes de Steps 5-7) → falla en compilación: `The method 'getAllProgress' isn't defined for the type 'MockHiveLocalDataSource'`, `The method 'getAll' isn't defined for the type 'HiveProgressRepository'`, `The method 'upsertProgress' isn't defined...`, `The method 'upsertAll' isn't defined...` (4 errores de compilación, reproduciendo exactamente lo esperado por el brief).
  - **GREEN (Step 8):** tras Steps 5-7 + regenerar mocks → `flutter test test/infrastructure/repositories/hive_progress_repository_test.dart` → "00:00 +8: All tests passed!" (8/8: 6 grupos previos intactos + `getAll` + `upsertAll`).
  - Verificación adicional: `flutter test test/domain/repositories/i_level_progress_repository_test.dart` → "00:00 +4: All tests passed!" (4/4, contrato LSP sigue verde tras el fix del fake).
  - **Analyze (Step 9):** `flutter analyze lib/domain/board/repositories/i_level_progress_repository.dart lib/infrastructure` → "No issues found!" (0.5s).
  - `grep -c bestScore lib/infrastructure/models/level_progress_hive_model.g.dart` → 2 (≥ 1 esperado por el brief).
**Modificaciones realizadas por el equipo:**

## Entrada 045 — front#18 — remote progress repository (Dio)

**Fecha:** 2026-07-09
**Tarea o problema abordado:** front#18 — sync local progress with server. Cuarto fragmento: agregar el lado remoto del sync contra los endpoints `/progress` del back (back#8, ya mergeado) — un puerto de dominio `IRemoteProgressRepository` (pull/push), un `RemoteProgressDataSource` sobre Dio (HTTP crudo, sin mapear errores) y un `RemoteProgressRepository` adaptador que mapea `LevelProgress` ↔ el shape JSON del back, espejando el patrón existente de `auth_remote_data_source.dart`.
**Herramienta de IA utilizada:** Claude Opus 4.8 (1M context) — ejecución de subagent TDD
**Prompt o instrucción proporcionada:** > "Implementing Task 4: remote progress port + Dio repository — for the ArrowMaze Flutter frontend (front#18: sync local progress with server). Follow the brief's Steps 1–7 in order (define port → write failing test → confirm RED → datasource → repo → regen mocks + confirm GREEN → analyze + AI_HISTORY + commit). Use the code in the brief verbatim."
**Resultado obtenido:**
- `lib/domain/board/repositories/i_remote_progress_repository.dart`: nuevo puerto (DIP/ISP) — `abstract interface class IRemoteProgressRepository` con `Future<List<LevelProgress>> pull()` (GET /progress) y `Future<List<LevelProgress>> push(List<LevelProgress> progress)` (POST /progress, devuelve el merge idempotente del server). El dominio solo conoce este contrato pequeño; la infraestructura decide el transporte.
- `lib/infrastructure/data_sources/remote/remote_progress_data_source.dart`: `RemoteProgressDataSource(Dio)` con `Future<List<dynamic>> getProgress()` (`GET /progress`) y `Future<List<dynamic>> postProgress(List<Map<String, dynamic>> levels)` (`POST /progress` con body `{'levels': levels}`). Devuelve JSON crudo, no mapea errores (propaga `DioException`), espejando exactamente el patrón de `auth_remote_data_source.dart`.
- `lib/infrastructure/repositories/remote_progress_repository.dart`: `RemoteProgressRepository(RemoteProgressDataSource)` implementa el puerto. `pull()` mapea cada fila (`Map`) a `LevelProgress(levelId: LevelId(...), completed: ..., bestScore: int?, bestStars: int?)`. `push()` serializa cada `LevelProgress` a JSON omitiendo `bestScore`/`bestStars` cuando son `null` (spread condicional `if (p.bestScore != null) 'bestScore': p.bestScore`, ídem `bestStars` — campos opcionales del back) y mapea la respuesta mergeada de vuelta a `LevelProgress`.
- `test/infrastructure/repositories/remote_progress_repository_test.dart`: dos grupos — `pull` (`should_map_backend_rows_to_level_progress_when_pulling`, verifica el mapeo de 2 filas incluyendo el caso `bestScore/bestStars` null) y `push` (`should_serialize_progress_and_map_merged_response_when_pushing`, verifica vía `captureAny` que el payload serializado omite las claves null y que la respuesta se mapea de vuelta correctamente).
- `test/infrastructure/repositories/remote_progress_repository_test.mocks.dart` (generado con `build_runner`, `@GenerateMocks([RemoteProgressDataSource])`): `MockRemoteProgressDataSource`.
- TDD estricto verificado:
  - **RED (Step 3):** `flutter test test/infrastructure/repositories/remote_progress_repository_test.dart` (antes de Steps 4-6) → falla en compilación: `Error when reading '.../remote_progress_data_source.dart': No such file or directory`, `Error when reading '.../remote_progress_repository.dart': No such file or directory`, `Error when reading '.../remote_progress_repository_test.mocks.dart': No such file or directory`, `Undefined name 'RemoteProgressDataSource'`, `'RemoteProgressRepository' isn't a type` (reproduce exactamente lo esperado por el brief: datasource/repo no existen y el mock no está generado).
  - **GREEN (Step 6):** tras crear datasource + repo y `dart run build_runner build --delete-conflicting-outputs` → `flutter test test/infrastructure/repositories/remote_progress_repository_test.dart` → "00:00 +2: All tests passed!" (pull + push, 2/2).
  - **Analyze (Step 7):** `flutter analyze lib/domain/board/repositories/i_remote_progress_repository.dart lib/infrastructure/data_sources/remote/remote_progress_data_source.dart lib/infrastructure/repositories/remote_progress_repository.dart` → "No issues found!" (0.1s).
**Modificaciones realizadas por el equipo:**

## Entrada 046 — front#18 — SyncProgressUseCase

**Fecha:** 2026-07-09
**Tarea o problema abordado:** front#18 — sync local progress with server. Quinto y último fragmento del feature: el orquestador de capa `application` que ata las piezas de las Tasks 1-4 — `IRemoteProgressRepository.pull()`, `ILevelProgressRepository.getAll()`, `ProgressReconciler.reconcile()`, `IRemoteProgressRepository.push()`, `ILevelProgressRepository.upsertAll()` — y loguea el resultado vía `ILoggerService` (AOP). Si cualquier paso falla (fallo de red típico), el error se captura y loguea sin propagarse, para no romper el flujo de autenticación/UI.
**Herramienta de IA utilizada:** Claude Opus 4.8 (1M context) — ejecución de subagent TDD
**Prompt o instrucción proporcionada:** > "Implementing Task 5: SyncProgressUseCase — for the ArrowMaze Flutter frontend (front#18: sync local progress with server). Follow the brief's Steps 1–5 in order (write failing test → regen mocks + confirm RED → minimal implementation → confirm GREEN → analyze + AI_HISTORY + commit). Use the code in the brief verbatim."
**Resultado obtenido:**
- `lib/application/use_cases/sync_progress_use_case.dart`: `class SyncProgressUseCase` con constructor `(IRemoteProgressRepository remote, ILevelProgressRepository local, ProgressReconciler reconciler, ILoggerService logger)` (DIP: depende solo de puertos/servicio de dominio) y `Future<void> execute()`. `execute()` hace `pull()` → `getAll()` → `reconciler.reconcile(local, remote)` → `push(merged)` → `upsertAll(merged)` → `logger.log(...)` en un `try/catch` que en caso de excepción llama a `logger.error('Progress sync failed', _ctx, e)` y retorna sin relanzar (AOP: el manejo de errores no ensucia la lógica de negocio ni rompe el flujo de auth/UI ante fallos de red).
- `test/application/use_cases/sync_progress_use_case_test.dart`: dos casos — `should_pull_reconcile_push_and_persist_when_syncing` (mockea `remote.pull()` con bestScore 500 y `local.getAll()` con bestScore 900; verifica vía `captureAny` que tanto el `push` como el `upsertAll` reciben el merge con bestScore 900, confirmando que el mejor score gana y que el merge se pushea Y se persiste) y `should_not_throw_and_log_error_when_network_fails` (mockea `remote.pull()` lanzando `Exception('network down')`; verifica que `execute()` completa sin relanzar (`expectLater(act(), completes)`), que `logger.error` se llama exactamente una vez y que `local.upsertAll` nunca se invoca).
- `test/application/use_cases/sync_progress_use_case_test.mocks.dart` (generado con `build_runner`, `@GenerateMocks([IRemoteProgressRepository, ILevelProgressRepository, ILoggerService])`): `MockIRemoteProgressRepository`, `MockILevelProgressRepository`, `MockILoggerService`.
- TDD estricto verificado:
  - **RED (Step 2):** tras `dart run build_runner build --delete-conflicting-outputs` (que sí genera el `.mocks.dart`), `flutter test test/application/use_cases/sync_progress_use_case_test.dart` → falla en compilación: `Error when reading '.../sync_progress_use_case.dart': No such file or directory`, `'SyncProgressUseCase' isn't a type`, `Method not found: 'SyncProgressUseCase'` (reproduce exactamente lo esperado por el brief: el use case aún no existe).
  - **GREEN (Step 4):** tras crear `sync_progress_use_case.dart` → `flutter test test/application/use_cases/sync_progress_use_case_test.dart` → "00:00 +2: All tests passed!" (2/2).
  - **Analyze (Step 5):** `flutter analyze lib/application/use_cases/sync_progress_use_case.dart` → "No issues found!" (0.1s).
**Modificaciones realizadas por el equipo:**
