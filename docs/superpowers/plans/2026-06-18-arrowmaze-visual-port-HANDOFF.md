# HANDOFF — Ejecución del plan "Arrow Maze: Port Visual del Tablero"

> Documento de traspaso para que **otro agente** ejecute el plan **inline, sin subagentes**
> (para economizar tokens). Léelo entero antes de tocar código.

## Qué vas a hacer

Implementar, tarea por tarea, el plan de port visual del tablero de Arrow Maze (flechas con
cuerpo grueso multicolor, hit-testing por celda, animaciones shake/slide-out, pantallas pulidas
y tableros escalados por nivel), conservando la arquitectura actual.

## Documentos fuente (léelos primero, en este orden)

1. **Spec (qué y por qué):** `docs/superpowers/specs/2026-06-18-arrowmaze-visual-port-design.md`
2. **Plan (cómo, paso a paso):** `docs/superpowers/plans/2026-06-18-arrowmaze-visual-port.md`

El plan es la fuente de verdad de ejecución: tiene 6 fases, ~18 tareas TDD, cada step con código
real, paths exactos y comandos con su salida esperada.

## Método de ejecución (IMPORTANTE)

- Usa la skill **`superpowers:executing-plans`** (ejecución inline por lotes con checkpoints).
- **NO uses subagentes** (no `subagent-driven-development`, no `Agent`/`Task`): el usuario lo pidió
  explícitamente para ahorrar tokens. Trabaja todo en el hilo principal.
- **Disciplina TDD por step**, sin atajos: escribir el test que falla → correrlo y verlo fallar →
  implementar lo mínimo → correrlo y verlo pasar → commit. No escribas la implementación antes del test.
- Ejecuta las fases **en orden (1 → 6)** y, dentro de cada fase, las tareas en orden. Marca cada
  checkbox `- [ ]` del plan a medida que completes el step.
- Haz un **checkpoint con el usuario al terminar cada FASE** (resumen breve + resultado de
  `flutter test` de esa fase) antes de seguir con la siguiente.

## Entorno

- **Directorio de trabajo:** `MazePruebaFront/` (el artefacto Flutter). Es su propio repo git en la
  rama `feat/main-sprint`. (La carpeta raíz `ArrowMaze/` NO es git; el repo es `MazePruebaFront/`.)
- **Nombre del package:** `flutter_arrow_maze` (todos los imports de test del plan ya lo usan).
- **Shell:** PowerShell en Windows.

### Pre-flight (antes de la Task 1.1)

```bash
flutter pub get
flutter analyze   # foto del estado inicial (puede tener warnings previos)
flutter test      # debería pasar / no haber tests aún
```

### Comandos clave

- Un test: `flutter test <ruta>`   ·   Todos: `flutter test`   ·   Lint: `flutter analyze`
- **Codegen de mocks (mockito):** `dart run build_runner build --delete-conflicting-outputs`
  - Obligatorio ANTES de correr los tests de **Task 4.2** (`game_controller_test`) y
    **Task 5.3** (`board_widget_hit_test`), que usan `@GenerateMocks`.

## Reglas de commits (la ejecución SÍ commitea)

Durante la planificación no se commiteó nada (decisión del usuario). **Al ejecutar, cada tarea
termina con commit**, según CLAUDE.md:

1. Añadir una entrada en `MazePruebaFront/AI_HISTORY.MD` con la plantilla de CLAUDE.md
   (Fecha, Tarea, Herramienta de IA, Prompt, Resultado).
2. Commit **Conventional Commits** con el mensaje que indica cada Task (`<tipo>(front[/ámbito]): …`).
3. Un commit por fragmento; no acumular varias tareas en un commit.
4. Si una tarea cambia superficie pública (arquitectura/mecánica), actualizar `README.md`.

> Si el usuario prefiere revisar antes de commitear, que te lo diga; por defecto, commitea por tarea.

## Cosas que ya se verificaron (no las re-descubras)

- El package es `flutter_arrow_maze` (no `maze_prueba_front`).
- `ArrowLength(int)` y `Position({row,col})` **no** son `const` (validan en el cuerpo);
  `ArrowId(String)` y `Arrow({...})` **sí** aceptan `const`.
- **mockito:** si un argumento de `verify`/`when` es matcher (`any`), TODOS deben serlo
  (usa `argThat(equals(...))`), no mezclar matcher con literal.
- El plan corrige de paso 2 bugs latentes: undo desde `GameWon` con dimensiones 4×4 hardcodeadas, y
  la pantalla de victoria mostrando siempre "0 movimientos".

## Expectativas de estado intermedio (no te asustes)

- `flutter analyze` mostrará **errores hasta la Fase 5/6**: al cambiar la paleta (Fase 1) y el estado
  (Fase 4), archivos de UI que aún no se han reescrito siguen referenciando `arrowUp/Down/Left/Right`
  o la firma vieja del painter. Es esperado. El criterio por tarea es que **su** test (el del step)
  pase; el `flutter analyze` global limpio se exige al final de la Fase 5 y de nuevo en la Fase 6.
- Tras Fase 4 toda la lógica (sin UI) está testeada y verde.
- Tras Fase 6, `flutter test` completo verde y `flutter analyze` limpio.

## Manejo de desviaciones

- Si un test no falla/pasa como dice el plan, **detente y diagnostica** (systematic-debugging); no
  parchees a ciegas ni borres aserciones para "que pase".
- Si encuentras que el código real difiere de lo que el plan asume (el plan se escribió contra el
  estado actual de `feat/main-sprint`), reporta la diferencia al usuario antes de improvisar.
- La curva de dificultad de `LevelBlueprint.forLevel` es ajustable; si los tableros salen muy
  vacíos/llenos, es tuning de esa única función (no toca generador ni UI).

## Estado al momento del handoff

- Spec y plan **escritos y guardados, NO commiteados**.
- `AI_HISTORY.MD` **sin tocar** todavía.
- Código de producción: **sin cambios** (rama `feat/main-sprint` tal cual).
- Punto de arranque: **Fase 1 · Task 1.1**.
