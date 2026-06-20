# Flechas dobladas, tablero vertical denso y salida serpiente — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generalizar la flecha de "recta" a "camino" para que doble en varias direcciones, poblar el tablero con una curva vertical-densa y darle una salida "serpiente" (cabeza primero) realista.

**Architecture:** `Arrow` pasa a ser un camino (`List<Position>` cola→cabeza + `headDirection`); recta es un caso degenerado. El render (polilínea) y el hit-testing (por celda) ya son agnósticos a la forma, y la condición de salida (rayo recto desde la cabeza) se conserva, por lo que la solubilidad por construcción (DAG), el determinismo por seed y el undo se mantienen. El generador construye cuerpos mediante una caminata aleatoria auto-evitante crecida hacia atrás desde una cabeza con carril libre.

**Tech Stack:** Flutter/Dart, Riverpod, Hive CE, Mockito + build_runner, flutter_test.

## Global Constraints

- **Paquete/imports:** prefijo `package:flutter_arrow_maze/...`.
- **Comandos:** tests `flutter test`; análisis estático `flutter analyze` (cero issues nuevos); regenerar mocks `dart run build_runner build --delete-conflicting-outputs`.
- **Arquitectura (Clean Mobile):** `domain/` es Dart puro (sin Flutter); `presentation/` consume solo `application/`; nunca llamar a `infrastructure/`/`domain/` desde la UI.
- **Pruebas (override del usuario, prioridad sobre TDD inline):** las tareas de prueba NO vuelcan código de tests en el plan. Cada paso "Delegar tests" es un prompt para un subagente `arrowmaze-qa` (o `qa-engineer`) que escribe/migra las pruebas siguiendo **AAA**, mockeando dependencias externas, y dejando `flutter test` en verde **antes** del commit. El plan describe QUÉ casos cubrir; el subagente produce el código.
- **Commits por fragmento (Conventional Commits):** un commit por tarea, nunca acumular fragmentos. Cada commit incluye una entrada nueva en `AI_HISTORY.MD` (formato `## Entrada NNN — <título>`, con Fecha 2026-06-20, herramienta, prompt, resultado) y, si cambia comportamiento público, `MazePruebaFront/README.md`. Terminar el mensaje del commit con el trailer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **Estado del árbol:** ya hay WIP no relacionado (prevención de solapamiento integrada en `ArrowBoard.overlaps`, rediseño de la home). No lo incluyas en estos commits salvo `ArrowBoard.overlaps`, del que dependemos.

---

### Task 1: `Arrow` como camino + `Arrow.straight` + retiro de `ArrowLength`

**Files:**
- Modify: `lib/domain/arrows/entities/arrow.dart` (reescritura)
- Delete: `lib/domain/arrows/value_objects/arrow_length.dart`
- Delete: `test/domain/value_objects/arrow_length_test.dart`
- Modify (compilar): `lib/infrastructure/generators/graph_board_generator.dart` (usar `Arrow.straight`, quitar import de `ArrowLength`)
- Test (delegado): todo el árbol `test/**` que construya `Arrow(...)` o use `ArrowLength`

**Interfaces:**
- Produces:
  - `class Arrow { final ArrowId id; final List<Position> cells; final Direction headDirection; const Arrow({required id, required cells, required headDirection}); }`
  - `factory Arrow.straight({required ArrowId id, required Position tail, required Direction direction, required int length})`
  - getters: `Position get head => cells.last;` `Position get tail => cells.first;` `Direction get direction => headDirection;` `int get length => cells.length;`
  - `List<Position> exitPath(int cols, int rows)` (rayo recto desde `head` en `headDirection` hasta el borde)
- Consumes: `ArrowBoard.overlaps` / `canExit` / `arrowAt` (ya operan sobre `cells`, sin cambios).

- [ ] **Step 1: Reescribir `Arrow` al modelo de camino**

Reemplaza el contenido de `lib/domain/arrows/entities/arrow.dart` por:

```dart
import 'package:equatable/equatable.dart';
import '../value_objects/arrow_id.dart';
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';

/// Flecha como CAMINO: `cells` va de la cola (first) a la cabeza (last), con
/// celdas ortogonalmente adyacentes y sin repetir. Una flecha recta es el caso
/// degenerado (sin curvas). `headDirection` es la dirección por la que la cabeza
/// abandona el tablero (mecánica "serpiente": el cuerpo se retrae por su propio
/// camino, así que la salida solo depende del carril recto frente a la cabeza).
class Arrow extends Equatable {
  final ArrowId id;
  final List<Position> cells;
  final Direction headDirection;

  const Arrow({
    required this.id,
    required this.cells,
    required this.headDirection,
  });

  /// Conveniencia para flechas rectas: genera `length` celdas desde `tail` en
  /// `direction`. Mantiene ergonómicos los call sites que no necesitan curvas.
  factory Arrow.straight({
    required ArrowId id,
    required Position tail,
    required Direction direction,
    required int length,
  }) {
    assert(length >= 1, 'length must be >= 1');
    final cells = List<Position>.generate(length, (i) => switch (direction) {
          Direction.right => Position(row: tail.row, col: tail.col + i),
          Direction.left => Position(row: tail.row, col: tail.col - i),
          Direction.down => Position(row: tail.row + i, col: tail.col),
          Direction.up => Position(row: tail.row - i, col: tail.col),
        });
    return Arrow(id: id, cells: cells, headDirection: direction);
  }

  Position get head => cells.last;
  Position get tail => cells.first;
  Direction get direction => headDirection; // compat para widgets/animaciones
  int get length => cells.length;

  /// Celdas libres que debe recorrer la cabeza para salir del tablero.
  List<Position> exitPath(int cols, int rows) {
    final h = head;
    return switch (headDirection) {
      Direction.right => List.generate(
          cols - 1 - h.col, (i) => Position(row: h.row, col: h.col + 1 + i)),
      Direction.left => List.generate(
          h.col, (i) => Position(row: h.row, col: h.col - 1 - i)),
      Direction.down => List.generate(
          rows - 1 - h.row, (i) => Position(row: h.row + 1 + i, col: h.col)),
      Direction.up => List.generate(
          h.row, (i) => Position(row: h.row - 1 - i, col: h.col)),
    };
  }

  @override
  List<Object?> get props => [id, cells, headDirection];
}
```

- [ ] **Step 2: Retirar `ArrowLength`**

Borra `lib/domain/arrows/value_objects/arrow_length.dart` y `test/domain/value_objects/arrow_length_test.dart`.

```bash
git rm lib/domain/arrows/value_objects/arrow_length.dart test/domain/value_objects/arrow_length_test.dart
```

- [ ] **Step 3: Hacer compilar el generador (interino, recto)**

En `lib/infrastructure/generators/graph_board_generator.dart`: quita el `import` de `arrow_length.dart` y sustituye la construcción final de `_randomArrow` por la fábrica recta (la lógica bent llega en Task 3):

```dart
return Arrow.straight(
  id: ArrowId('arrow-$index'),
  tail: Position(row: row, col: col),
  direction: dir,
  length: length,
);
```

- [ ] **Step 4: Delegar migración + tests al subagente qa**

Dispatch a `arrowmaze-qa` con este prompt:

> Contexto: en `MazePruebaFront` la entidad `Arrow` (`lib/domain/arrows/entities/arrow.dart`) cambió de `{id, tail, direction, length: ArrowLength}` a un modelo de camino `{id, List<Position> cells, Direction headDirection}`, con `factory Arrow.straight({id, tail, direction, length:int})` y getters de compat `head/tail/direction/length`. Se eliminó el VO `ArrowLength`.
> Tarea 1 (migración mecánica): recorre todo `test/**` y `lib/**` y reemplaza cada construcción `Arrow(id:…, tail:…, direction:…, length: ArrowLength(n))` por `Arrow.straight(id:…, tail:…, direction:…, length: n)`; elimina imports a `arrow_length.dart`. Deja la suite COMPILANDO.
> Tarea 2 (tests del dominio): reescribe `test/domain/entities/arrow_test.dart` con AAA cubriendo, sobre caminos DOBLADOS además de rectos: `cells` cola→cabeza; `head`/`tail`/`length`/`direction(=headDirection)`; `exitPath` produce el rayo recto correcto desde la cabeza en `headDirection` para las 4 direcciones y se vacía en el borde; y un caso con CURVA justo en la cabeza (último segmento del cuerpo perpendicular a `headDirection`) verificando que `exitPath` sigue `headDirection` y no el último segmento. Añade un caso de `Arrow.straight` equivalente a un camino recto explícito (igualdad por Equatable).
> Ejecuta `flutter test test/domain/entities/arrow_test.dart` y luego `flutter test` completo; todo en verde. Reporta archivos tocados.

- [ ] **Step 5: Verificar suite y análisis**

Run: `flutter test` → Expected: PASS (toda la suite migrada). Run: `flutter analyze` → Expected: sin issues nuevos.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/arrows/entities/arrow.dart lib/infrastructure/generators/graph_board_generator.dart test/ AI_HISTORY.MD
git commit -m "refactor(front/domain): model Arrow as a path with headDirection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `ArrowPainter` orienta la punta por `headDirection`

**Files:**
- Modify: `lib/presentation/game/painters/arrow_painter.dart`
- Modify: `lib/presentation/game/widgets/arrow_widget.dart` (pasar `headDirection`)
- Test (delegado): `test/presentation/game/painters/arrow_painter_test.dart`

**Interfaces:**
- Consumes: `Arrow.headDirection`, `Arrow.cells` (Task 1).
- Produces: `ArrowPainter({required List<Position> cells, required int minCol, required int minRow, required double cell, required Color color, required Direction headDirection})` — la punta se orienta por `headDirection`.

- [ ] **Step 1: Añadir `headDirection` al painter y orientar la punta**

En `arrow_painter.dart`: añade `import '../../../domain/game_core/value_objects/direction.dart';`, el campo `final Direction headDirection;` al constructor, e implementa la orientación de la punta por dirección (reemplaza el cálculo por `atan2` del último segmento):

```dart
void _drawHead(Canvas canvas, double stroke) {
  final tip = _center(cells.last);
  final angle = switch (headDirection) {
    Direction.right => 0.0,
    Direction.left => math.pi,
    Direction.down => math.pi / 2,
    Direction.up => -math.pi / 2,
  };
  final headLen = stroke * 1.2;
  final headHalf = stroke * 0.95;
  final apex = Offset(
    tip.dx + math.cos(angle) * (cell * 0.5),
    tip.dy + math.sin(angle) * (cell * 0.5),
  );
  final base = Offset(
    apex.dx - math.cos(angle) * headLen,
    apex.dy - math.sin(angle) * headLen,
  );
  final perp = angle + math.pi / 2;
  final left = Offset(
    base.dx + math.cos(perp) * headHalf,
    base.dy + math.sin(perp) * headHalf,
  );
  final right = Offset(
    base.dx - math.cos(perp) * headHalf,
    base.dy - math.sin(perp) * headHalf,
  );
  final head = Path()
    ..moveTo(apex.dx, apex.dy)
    ..lineTo(left.dx, left.dy)
    ..lineTo(right.dx, right.dy)
    ..close();
  canvas.drawPath(head, Paint()..color = color);
}
```

Añade `headDirection` a `shouldRepaint`: `|| old.headDirection != headDirection`.

- [ ] **Step 2: `ArrowWidget` pasa `headDirection`**

En `arrow_widget.dart`, en el `ArrowPainter(...)` interno añade `headDirection: widget.arrow.headDirection,`.

- [ ] **Step 3: Delegar tests al subagente qa**

Dispatch a `arrowmaze-qa`:

> En `MazePruebaFront`, `ArrowPainter` (`lib/presentation/game/painters/arrow_painter.dart`) ahora recibe `Direction headDirection` y orienta la punta por esa dirección (no por el último segmento del cuerpo). Actualiza `test/presentation/game/painters/arrow_painter_test.dart` (AAA): (a) migra los constructores para pasar `headDirection`; (b) añade un caso donde el cuerpo gira en la cabeza (último segmento perpendicular a `headDirection`) verificando que el ángulo/orientación de la punta corresponde a `headDirection` y no al último segmento. Usa el enfoque de testing de painter ya presente en ese archivo (no introduzcas dependencias nuevas). Deja `flutter test test/presentation/game/painters/arrow_painter_test.dart` y la suite completa en verde.

- [ ] **Step 4: Verificar y commitear**

Run: `flutter test` → PASS. Run: `flutter analyze` → sin issues.

```bash
git add lib/presentation/game/painters/arrow_painter.dart lib/presentation/game/widgets/arrow_widget.dart test/presentation/game/painters/arrow_painter_test.dart AI_HISTORY.MD
git commit -m "feat(front/presentation): orient arrowhead by headDirection

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Generación de flechas dobladas (caminata auto-evitante) + `maxPathLen` en el puerto

**Files:**
- Modify: `lib/domain/arrows/services/i_level_generator.dart` (añadir `required int maxPathLen`)
- Modify: `lib/infrastructure/generators/graph_board_generator.dart` (`_randomBentArrow` + firma)
- Regenerate: `test/application/state/game_controller_test.mocks.dart` (build_runner)
- Test (delegado): `test/infrastructure/generators/graph_board_generator_test.dart`, `test/domain/services/i_level_generator_test.dart`

**Interfaces:**
- Produces: `ArrowBoard generate({required int cols, required int rows, required int arrowCount, required int maxPathLen, int? seed})`.
- Consumes: `Arrow({id, cells, headDirection})`, `ArrowBoard.overlaps`, `ArrowBoard.canExit`.

- [ ] **Step 1: Extender el puerto `ILevelGenerator`**

En `lib/domain/arrows/services/i_level_generator.dart`, añade el parámetro requerido `maxPathLen`:

```dart
abstract interface class ILevelGenerator {
  /// Genera un tablero solucionable (construcción DAG). [maxPathLen] acota la
  /// longitud de los caminos doblados. [seed] hace la generación determinista.
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  });
}
```

- [ ] **Step 2: Reescribir el cuerpo del generador a caminos doblados**

En `lib/infrastructure/generators/graph_board_generator.dart`, actualiza `generate` (firma + paso de `occupied`) y reemplaza `_randomArrow` por `_randomBentArrow` con helpers. El bucle de validación `!overlaps && canExit` NO cambia (preserva el DAG):

```dart
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) {
    final rng = Random(seed);
    final placed = <Arrow>[];
    final maxAttempts = cols * rows * 30;
    var attempts = 0;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final occupied = <Position>{for (final a in placed) ...a.cells};
      final candidate =
          _randomBentArrow(rng, cols, rows, placed.length, maxPathLen, occupied);
      if (candidate == null) continue;

      final tempBoard =
          ArrowBoard(arrows: [...placed, candidate], cols: cols, rows: rows);
      if (!tempBoard.overlaps(candidate) && tempBoard.canExit(candidate.id)) {
        placed.add(candidate);
      }
    }

    if (placed.length < arrowCount) {
      _logger?.warn(
        'Graceful degradation: placed ${placed.length}/$arrowCount arrows '
        'in ${cols}x$rows board after $attempts attempts (seed=$seed)',
        'GraphBoardGenerator',
      );
    }

    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
  }

  /// Construye una flecha doblada: elige cabeza+dirección con carril de salida
  /// libre, reserva ese carril, y crece el cuerpo HACIA ATRÁS con una caminata
  /// aleatoria auto-evitante. Devuelve null si no logra un cuerpo de largo >= 2.
  Arrow? _randomBentArrow(Random rng, int cols, int rows, int index,
      int maxPathLen, Set<Position> occupied) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final head = _randomHeadWithClearLane(rng, cols, rows, dir, occupied);
    if (head == null) return null;

    // Reserva el carril de salida para que la flecha nunca bloquee su salida.
    final blocked = <Position>{...occupied, head, ..._lane(head, dir, cols, rows)};

    final body = <Position>[head]; // head..tail; se invierte al final
    final targetLen = 2 + rng.nextInt(maxPathLen - 1); // 2..maxPathLen
    var cursor = head;
    while (body.length < targetLen) {
      final options = _freeNeighbors(cursor, cols, rows, blocked);
      if (options.isEmpty) break; // acepta cuerpo más corto
      final next = options[rng.nextInt(options.length)];
      body.add(next);
      blocked.add(next);
      cursor = next;
    }
    if (body.length < 2) return null;

    return Arrow(
      id: ArrowId('arrow-$index'),
      cells: body.reversed.toList(), // cola (first) .. cabeza (last)
      headDirection: dir,
    );
  }

  /// Celdas del carril recto desde la cabeza (exclusive) hasta el borde en [dir].
  List<Position> _lane(Position head, Direction dir, int cols, int rows) {
    return switch (dir) {
      Direction.right => List.generate(
          cols - 1 - head.col, (i) => Position(row: head.row, col: head.col + 1 + i)),
      Direction.left => List.generate(
          head.col, (i) => Position(row: head.row, col: head.col - 1 - i)),
      Direction.down => List.generate(
          rows - 1 - head.row, (i) => Position(row: head.row + 1 + i, col: head.col)),
      Direction.up => List.generate(
          head.row, (i) => Position(row: head.row - 1 - i, col: head.col)),
    };
  }

  /// Busca (hasta 20 intentos) una celda-cabeza libre cuyo carril recto al
  /// borde en [dir] esté libre de [occupied].
  Position? _randomHeadWithClearLane(
      Random rng, int cols, int rows, Direction dir, Set<Position> occupied) {
    for (var t = 0; t < 20; t++) {
      final head = Position(row: rng.nextInt(rows), col: rng.nextInt(cols));
      if (occupied.contains(head)) continue;
      final lane = _lane(head, dir, cols, rows);
      if (lane.every((p) => !occupied.contains(p))) return head;
    }
    return null;
  }

  /// Vecinos ortogonales en rango que no están bloqueados.
  List<Position> _freeNeighbors(
      Position p, int cols, int rows, Set<Position> blocked) {
    final candidates = <Position>[
      if (p.row > 0) Position(row: p.row - 1, col: p.col),
      if (p.row < rows - 1) Position(row: p.row + 1, col: p.col),
      if (p.col > 0) Position(row: p.row, col: p.col - 1),
      if (p.col < cols - 1) Position(row: p.row, col: p.col + 1),
    ];
    return [for (final c in candidates) if (!blocked.contains(c)) c];
  }
```

- [ ] **Step 3: Regenerar mocks**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenera `test/application/state/game_controller_test.mocks.dart` con la nueva firma de `generate`.

- [ ] **Step 4: Delegar tests al subagente qa**

Dispatch a `arrowmaze-qa`:

> En `MazePruebaFront`, `GraphBoardGenerator.generate` y el puerto `ILevelGenerator.generate` ahora reciben `required int maxPathLen`, y el generador produce flechas DOBLADAS (`Arrow` con `cells` camino + `headDirection`) mediante caminata aleatoria auto-evitante crecida hacia atrás desde una cabeza con carril de salida libre.
> 1) Actualiza el stub de `test/domain/services/i_level_generator_test.dart` para la nueva firma (añade `maxPathLen`) usando `Arrow.straight`; mantén las aserciones de contrato (dimensiones, arrowCount, seed opcional).
> 2) Reescribe `test/infrastructure/generators/graph_board_generator_test.dart` (AAA) cubriendo, con seeds fijos: **determinismo** (mismo seed ⇒ tableros iguales); **sin solapes** (ninguna celda compartida entre flechas); **cuerpos válidos** (celdas ortogonalmente adyacentes, sin repetir, dentro de rango, `length>=2`, `length<=maxPathLen`); **carril de cabeza libre al colocar**; **solubilidad por construcción** (removiendo en orden INVERSO de colocación, cada flecha `canExit` justo antes de removerla hasta vaciar el tablero); y **degradación con gracia** (tablero pequeño/denso devuelve <arrowCount sin lanzar, registrando vía logger mockeado). Mockea `ILoggerService` para aislar.
> 3) Si `game_controller_test.dart` rompe por la nueva firma del mock, ajústalo (el mock ya fue regenerado por build_runner).
> Ejecuta `flutter test` completo en verde. Reporta archivos tocados.

- [ ] **Step 5: Verificar y commitear**

Run: `flutter test` → PASS. Run: `flutter analyze` → sin issues.

```bash
git add lib/domain/arrows/services/i_level_generator.dart lib/infrastructure/generators/graph_board_generator.dart test/ AI_HISTORY.MD
git commit -m "feat(front/infra): generate bent self-avoiding arrows with maxPathLen

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `LevelBlueprint` vertical-denso + `maxPathLen`, y cableado en `GameController`

**Files:**
- Modify: `lib/domain/board/value_objects/level_blueprint.dart`
- Modify: `lib/application/state/game_controller.dart` (pasar `maxPathLen`)
- Test (delegado): `test/domain/board/value_objects/level_blueprint_test.dart`

**Interfaces:**
- Produces: `LevelBlueprint({required int cols, required int rows, required int arrowCount, required int maxPathLen})` y `factory LevelBlueprint.forLevel(int level)`.
- Consumes: `ILevelGenerator.generate(... maxPathLen: ...)` (Task 3).

- [ ] **Step 1: Nueva curva vertical-densa + campo `maxPathLen`**

Reemplaza el contenido relevante de `lib/domain/board/value_objects/level_blueprint.dart`:

```dart
class LevelBlueprint {
  final int cols;
  final int rows;
  final int arrowCount;
  final int maxPathLen;

  const LevelBlueprint({
    required this.cols,
    required this.rows,
    required this.arrowCount,
    required this.maxPathLen,
  });

  /// Curva vertical-densa: tablero más alto que ancho que crece ~6x8 → ~11x15,
  /// relleno ~68 % con caminos doblados cuyo largo máximo crece de 3 a 12.
  factory LevelBlueprint.forLevel(int level) {
    final lvl = level < 1 ? 1 : level;
    final width = (6 + (lvl - 1) ~/ 3).clamp(6, 11);
    final height = (8 + (lvl - 1) ~/ 2).clamp(8, 15);
    final maxPathLen = (3 + (lvl - 1) ~/ 2).clamp(3, 12);
    final avgPathLen = (2 + maxPathLen) / 2;
    final arrowCount = (width * height * 0.68 / avgPathLen)
        .round()
        .clamp(4, width * height);
    return LevelBlueprint(
      cols: width,
      rows: height,
      arrowCount: arrowCount,
      maxPathLen: maxPathLen,
    );
  }
}
```

- [ ] **Step 2: Pasar `maxPathLen` desde `GameController.loadLevel`**

En `lib/application/state/game_controller.dart`, en la llamada `_generator.generate(...)` de `loadLevel`, añade `maxPathLen: bp.maxPathLen,`. (El bloque de `undoMove` que reconstruye un `ArrowBoard` vacío desde `LevelBlueprint.forLevel(...)` no necesita cambios.)

- [ ] **Step 3: Delegar tests al subagente qa**

Dispatch a `arrowmaze-qa`:

> En `MazePruebaFront`, `LevelBlueprint` ganó el campo `maxPathLen` y `LevelBlueprint.forLevel` usa una curva vertical-densa: `width=(6+(lvl-1)~/3).clamp(6,11)`, `height=(8+(lvl-1)~/2).clamp(8,15)`, `maxPathLen=(3+(lvl-1)~/2).clamp(3,12)`, `arrowCount=(width*height*0.68/((2+maxPathLen)/2)).round().clamp(4, width*height)`. Reescribe `test/domain/board/value_objects/level_blueprint_test.dart` (AAA) verificando: nivel 1 = 6x8 con `maxPathLen` 3; el tablero es vertical (`rows>=cols`) en toda la curva; los clamps superiores (niveles altos ⇒ 11x15, `maxPathLen` 12); `arrowCount` dentro de `[4, width*height]`; y monotonía no decreciente de `width`/`height`/`maxPathLen` respecto al nivel. Si otros tests construyen `LevelBlueprint(...)` directamente, añádeles `maxPathLen`. Deja `flutter test` en verde.

- [ ] **Step 4: Verificar y commitear**

Run: `flutter test` → PASS. Run: `flutter analyze` → sin issues.

```bash
git add lib/domain/board/value_objects/level_blueprint.dart lib/application/state/game_controller.dart test/domain/board/value_objects/level_blueprint_test.dart AI_HISTORY.MD
git commit -m "feat(front/domain): vertical dense difficulty curve with maxPathLen

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Salida serpiente — `SnakeExitPainter` + reescritura de `ExitingArrowWidget`

**Files:**
- Create: `lib/presentation/game/painters/snake_exit_painter.dart`
- Modify: `lib/presentation/game/widgets/exiting_arrow_widget.dart` (reescritura)
- Modify: `lib/presentation/game/widgets/board_widget.dart` (pasar `cols`/`rows`, quitar `travel`)
- Test (delegado): `test/presentation/game/widgets/exiting_arrow_widget_test.dart` (+ painter si aplica)

**Interfaces:**
- Produces:
  - `SnakeExitPainter({required List<Position> cells, required Direction headDirection, required int minCol, required int minRow, required int cols, required int rows, required double cell, required Color color, required double progress})`
  - `ExitingArrowWidget({required Arrow arrow, required int minCol, required int minRow, required int cols, required int rows, required double cell, required Color color, required int nonce})` (sin `travel`)
- Consumes: `Arrow.cells`, `Arrow.headDirection` (Task 1); el `Stack` con `clipBehavior: Clip.none` de `BoardWidget`.

- [ ] **Step 1: Crear `SnakeExitPainter`**

Crea `lib/presentation/game/painters/snake_exit_painter.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';

/// Retracción "serpiente": construye la trayectoria (centros del cuerpo
/// cola→cabeza ++ carril recto más allá del borde) y, a progreso [progress],
/// desplaza cada vértice del cuerpo esa distancia de arco hacia delante. La
/// cabeza sale primero y la cola la sigue por el mismo camino.
class SnakeExitPainter extends CustomPainter {
  final List<Position> cells; // cola (first) .. cabeza (last)
  final Direction headDirection;
  final int minCol;
  final int minRow;
  final int cols;
  final int rows;
  final double cell;
  final Color color;
  final double progress; // 0..1

  const SnakeExitPainter({
    required this.cells,
    required this.headDirection,
    required this.minCol,
    required this.minRow,
    required this.cols,
    required this.rows,
    required this.cell,
    required this.color,
    required this.progress,
  });

  Offset _center(Position p) => Offset(
        (p.col - minCol + 0.5) * cell,
        (p.row - minRow + 0.5) * cell,
      );

  Offset _dirUnit() => switch (headDirection) {
        Direction.up => const Offset(0, -1),
        Direction.down => const Offset(0, 1),
        Direction.left => const Offset(-1, 0),
        Direction.right => const Offset(1, 0),
      };

  int _laneCells() {
    final h = cells.last;
    return switch (headDirection) {
      Direction.right => cols - 1 - h.col,
      Direction.left => h.col,
      Direction.down => rows - 1 - h.row,
      Direction.up => h.row,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;

    final traj = <Offset>[for (final p in cells) _center(p)];
    final unit = _dirUnit();
    final headC = traj.last;
    final beyond = cells.length + _laneCells() + 1; // margen para salir entero
    for (var i = 1; i <= beyond; i++) {
      traj.add(Offset(headC.dx + unit.dx * i * cell, headC.dy + unit.dy * i * cell));
    }

    final cum = <double>[0];
    for (var i = 1; i < traj.length; i++) {
      cum.add(cum[i - 1] + (traj[i] - traj[i - 1]).distance);
    }

    final bodyArc = cum[cells.length - 1];
    final laneArc = _laneCells() * cell;
    final shift = progress * (bodyArc + laneArc); // a t=1 la cola cruza el borde

    final pts = <Offset>[
      for (var k = 0; k < cells.length; k++) _along(traj, cum, cum[k] + shift),
    ];

    _strokeBody(canvas, pts);
    _drawHead(canvas, pts.last, unit);
  }

  Offset _along(List<Offset> traj, List<double> cum, double d) {
    if (d <= 0) return traj.first;
    if (d >= cum.last) return traj.last;
    var i = 1;
    while (i < cum.length && cum[i] < d) {
      i++;
    }
    final t = (d - cum[i - 1]) / (cum[i] - cum[i - 1]);
    return Offset.lerp(traj[i - 1], traj[i], t)!;
  }

  void _strokeBody(Canvas canvas, List<Offset> pts) {
    final stroke = cell * 0.40;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.45),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawHead(Canvas canvas, Offset tip, Offset unit) {
    final stroke = cell * 0.40;
    final angle = math.atan2(unit.dy, unit.dx);
    final headLen = stroke * 1.2;
    final headHalf = stroke * 0.95;
    final apex = Offset(tip.dx + unit.dx * cell * 0.5, tip.dy + unit.dy * cell * 0.5);
    final base =
        Offset(apex.dx - math.cos(angle) * headLen, apex.dy - math.sin(angle) * headLen);
    final perp = angle + math.pi / 2;
    final left =
        Offset(base.dx + math.cos(perp) * headHalf, base.dy + math.sin(perp) * headHalf);
    final right =
        Offset(base.dx - math.cos(perp) * headHalf, base.dy - math.sin(perp) * headHalf);
    canvas.drawPath(
      Path()
        ..moveTo(apex.dx, apex.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant SnakeExitPainter old) =>
      old.progress != progress ||
      old.cells != cells ||
      old.color != color ||
      old.cell != cell;
}
```

- [ ] **Step 2: Reescribir `ExitingArrowWidget`**

Reemplaza `lib/presentation/game/widgets/exiting_arrow_widget.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../painters/snake_exit_painter.dart';

/// Overlay cosmético de la flecha removida: retracción "serpiente" cabeza
/// primero (la cabeza sale y la cola la sigue por su propio camino). Auto-
/// desmontable: al terminar renderiza vacío. Keyed por `exitNonce` para que
/// cada salida re-anime.
class ExitingArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final int minCol;
  final int minRow;
  final int cols;
  final int rows;
  final double cell;
  final Color color;
  final int nonce;

  const ExitingArrowWidget({
    super.key,
    required this.arrow,
    required this.minCol,
    required this.minRow,
    required this.cols,
    required this.rows,
    required this.cell,
    required this.color,
    required this.nonce,
  });

  @override
  State<ExitingArrowWidget> createState() => _ExitingArrowWidgetState();
}

class _ExitingArrowWidgetState extends State<ExitingArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (_c.isCompleted) return const SizedBox.shrink();
          final t = Curves.easeIn.transform(_c.value);
          return CustomPaint(
            size: Size.infinite,
            painter: SnakeExitPainter(
              cells: widget.arrow.cells,
              headDirection: widget.arrow.headDirection,
              minCol: widget.minCol,
              minRow: widget.minRow,
              cols: widget.cols,
              rows: widget.rows,
              cell: widget.cell,
              color: widget.color,
              progress: t,
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: `BoardWidget` pasa `cols`/`rows` (y elimina `travel`)**

En `lib/presentation/game/widgets/board_widget.dart`:
- Cambia la llamada del overlay a `_positionExiting(state.exitingArrow!, cell, state.exitNonce, board.cols, board.rows)` (elimina el argumento `math.max(width, height)`).
- Reemplaza `_positionExiting` por:

```dart
  Widget _positionExiting(
      Arrow arrow, double cell, int nonce, int cols, int rows) {
    final b = _bounds(arrow);
    return Positioned(
      left: b.minCol * cell,
      top: b.minRow * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      child: ExitingArrowWidget(
        key: ValueKey('exiting-$nonce'),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cols: cols,
        rows: rows,
        cell: cell,
        color: arrowColorFor(arrow.id),
        nonce: nonce,
      ),
    );
  }
```

(Si tras quitar `math.max(width,height)` el import `dart:math as math` queda sin uso en otras partes del archivo, déjalo: `cell` se calcula con `math.min`. No lo elimines.)

- [ ] **Step 4: Delegar tests al subagente qa**

Dispatch a `arrowmaze-qa`:

> En `MazePruebaFront` se añadió `SnakeExitPainter` (`lib/presentation/game/painters/snake_exit_painter.dart`) y `ExitingArrowWidget` (`lib/presentation/game/widgets/exiting_arrow_widget.dart`) se reescribió: ahora recibe `{arrow, minCol, minRow, cols, rows, cell, color, nonce}` (SIN `travel`) y anima una retracción serpiente vía `SnakeExitPainter(progress:)`. Reescribe `test/presentation/game/widgets/exiting_arrow_widget_test.dart` (AAA, `flutter_test`) cubriendo: monta el widget con una flecha DOBLADA y verifica que (a) construye sin throw y pinta un `CustomPaint` con `SnakeExitPainter`; (b) tras `tester.pump` avanzando la animación el painter recibe `progress` creciente (puedes exponer/inspeccionar vía `find.byType(CustomPaint)` y casteo del painter); (c) al completarse la animación el widget colapsa a `SizedBox.shrink`. Migra cualquier construcción previa de `ExitingArrowWidget` (p. ej. en `board_widget_test.dart`/`game_screen_test.dart`) a la nueva firma. Si conviene, añade un test de unidad mínimo del `SnakeExitPainter` (no-throw + `shouldRepaint` true al cambiar `progress`). Deja `flutter test` completo en verde.

- [ ] **Step 5: Verificar y commitear**

Run: `flutter test` → PASS. Run: `flutter analyze` → sin issues.

```bash
git add lib/presentation/game/painters/snake_exit_painter.dart lib/presentation/game/widgets/exiting_arrow_widget.dart lib/presentation/game/widgets/board_widget.dart test/ AI_HISTORY.MD
git commit -m "feat(front/presentation): snake-style head-first exit retraction

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: Documentación pública (README) y cierre

**Files:**
- Modify: `MazePruebaFront/README.md`
- Modify: `MazePruebaFront/AI_HISTORY.MD` (entrada de cierre)

**Interfaces:** ninguna (solo documentación).

- [ ] **Step 1: Actualizar README**

En `MazePruebaFront/README.md`, en la sección de mecánica de juego/arquitectura, documenta el comportamiento público nuevo: flechas que doblan (modelo de camino `Arrow` con `cells` + `headDirection`), tablero vertical denso (curva `LevelBlueprint.forLevel`, ~6x8 → ~11x15, `maxPathLen`), y la salida "serpiente" (la cabeza sale y el cuerpo se retrae por su propio camino; solubilidad por construcción intacta).

- [ ] **Step 2: Entrada de cierre en AI_HISTORY**

Añade `## Entrada NNN — Flechas dobladas, tablero vertical denso y salida serpiente` con Fecha 2026-06-20 resumiendo el sprint (referencia al spec `docs/superpowers/specs/2026-06-20-flechas-dobladas-tablero-vertical-design.md` y al plan).

- [ ] **Step 3: Verificación final**

Run: `flutter analyze` → sin issues. Run: `flutter test` → PASS (toda la suite). Verifica manualmente (opcional) `flutter run` y juega un nivel alto: las flechas doblan, el tablero es vertical y denso, y la salida serpentea.

- [ ] **Step 4: Commit**

```bash
git add README.md AI_HISTORY.MD
git commit -m "docs(front): document bent arrows, vertical board and snake exit

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Cobertura del spec → tareas:**
- §4.1 `Arrow` camino + retiro `ArrowLength` → Task 1. `ArrowBoard` sin cambios (verificado: `overlaps`/`canExit`/`arrowAt` ya usan `cells`).
- §4.2 generador caminata auto-evitante cabeza-primero + carril reservado + DAG/determinismo/degradación → Task 3.
- §4.3 curva vertical-densa + `maxPathLen` (param explícito de `generate`) → Task 3 (puerto) + Task 4 (blueprint/cableado).
- §4.4 punta por `headDirection` → Task 2.
- §4.5 `SnakeExitPainter` + slither → Task 5.
- §4.6 errores/estado sin cambios → sin tarea (correcto).
- §5 pruebas (Arrow, generador, blueprint, painter) → delegadas en Tasks 1–5.
- §6 alcance/archivos → cubierto. Nota: el spec mencionaba propagar `headDirection` en `board_widget` para el painter; verificado que `BoardWidget` NO construye `ArrowPainter` directamente (lo hace `ArrowWidget`), así que el único cambio de `BoardWidget` es pasar `cols`/`rows` al overlay de salida (Task 5).
- §7 proceso (AI_HISTORY/commits/README) → trailers y entradas por tarea + Task 6.

**Escaneo de placeholders:** sin TBD/TODO; todo paso de código incluye el código; tests expresados como prompts de delegación por decisión explícita del usuario (override registrado en Global Constraints).

**Consistencia de tipos:** `generate({cols, rows, arrowCount, maxPathLen, seed})` idéntico en puerto (Task 3) e impl (Task 3) y llamada (Task 4). `Arrow({id, cells, headDirection})` + `Arrow.straight({id, tail, direction, length})` usados consistentemente en Tasks 1–5. `ExitingArrowWidget({arrow, minCol, minRow, cols, rows, cell, color, nonce})` coincide entre Task 5 Step 2 y la llamada de `BoardWidget` en Step 3. `SnakeExitPainter` firma idéntica entre creación (Step 1) y uso (Step 2).
