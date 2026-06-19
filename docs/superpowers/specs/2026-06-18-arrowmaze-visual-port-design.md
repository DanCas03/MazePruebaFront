# Arrow Maze — Port visual del tablero a `feat/main-sprint`

**Fecha:** 2026-06-18
**Artefacto:** `MazePruebaFront/` (Flutter)
**Rama destino:** `feat/main-sprint`
**Rama de referencia visual:** `app-agentic-sprint`
**Estado:** Aprobado (diseño) — pendiente de plan de implementación
**Autor:** Daniel + asistente (sesión de brainstorming)

---

## 1. Contexto y problema

La rama `feat/main-sprint` tiene mejor arquitectura y documentación que `app-agentic-sprint`,
pero su interfaz se ve mal. Dos causas concretas en la capa de presentación:

1. **No se sabe qué flecha se toca (bug de hit-testing).** En `board_widget.dart` cada
   `ArrowWidget` se apila en un `Stack` **sin `Positioned`** y pinta con coordenadas absolutas
   de todo el tablero (`CustomPaint(size: Size.infinite)`). Resultado: el `GestureDetector` de
   **cada** flecha cubre el tablero completo y solo la de encima recibe todos los toques.
2. **Flechas sin cuerpo.** `arrow_painter.dart` dibuja un trazo fino (`strokeWidth = cellSize * 0.35`)
   y colorea **por dirección** (solo 4 colores). El objetivo tiene cuerpos gruesos, redondeados
   y **un color distinto por flecha**.

Además hay **código muerto**: `ExitingArrowWidget` (animación de salida) y el flag `isHighlighted`
existen pero **nunca se cablean** en `BoardWidget`; y `GameController.tapArrow` ignora en silencio
los movimientos bloqueados (sin feedback).

La rama `app-agentic-sprint` resuelve esto con una técnica de render más limpia (responsive,
una flecha por rectángulo posicionado, painter con cuerpo grueso, paleta jewel por flecha,
shake al bloquear, slide-out al salir, pantallas pulidas). El objetivo es **portar esos visuales
a `feat/main-sprint` conservando su arquitectura** (Clean Mobile Architecture: `domain/` puro,
`presentation/` consume solo `application/`).

### Referencias visuales
- **Objetivo inmediato:** mockups del tablero (píldora de nivel "12", flechas gruesas multicolor)
  y de la home ("ARROW MAZE" + "Despeja el tablero. Saca cada flecha." + botón "JUGAR").
- **Aspiración futura (NO en este pase):** capturas tipo "CUTE LEVELS" / "CHALLENGE AWAITS"
  con tableros grandes y densos y **flechas dobladas/conectadas en L** siguiendo un camino.

---

## 2. Objetivos y criterios de éxito

- **Flechas con cuerpo:** trazos gruesos, redondeados, con punta clara y glow, color por flecha.
- **Se sabe qué flecha se toca:** un toque dentro de la huella de una flecha actúa sobre **esa**
  flecha, sin ambigüedad.
- **Animaciones:** shake al tocar una flecha bloqueada; slide-out + fade al sacar una flecha;
  micro-transiciones de pantalla; trofeo elástico en victoria.
- **Look fiel a los mockups:** paleta índigo "jewel", home con logo animado, top bar con píldora
  de nivel + undo/restart, pantalla de victoria rediseñada.
- **Sin degradar la arquitectura:** `domain/` permanece puro; `presentation/` sigue consumiendo
  `application/`; el color es responsabilidad de presentación (no del dominio).
- **No cerrar la puerta a flechas dobladas:** el render e hit-testing son **agnósticos de la forma**.
- **Tableros escalados por nivel:** capacidad de tableros grandes y múltiples flechas que crecen con
  el número de nivel (el `4×4×5` fijo deja de existir).
- **Cobertura de tests** (AAA) para la lógica nueva/cambiada (hoy no hay tests en el front).

---

## 3. Decisiones tomadas (sesión de brainstorming)

| # | Decisión | Razón |
|---|----------|-------|
| D1 | **Enfoque A — port por adaptación** (no copia directa de archivos de la otra rama). | La otra rama tiene un dominio distinto; copiar la rompería. Adaptamos la técnica al dominio actual. |
| D2 | **Tema dual claro + oscuro** (se conserva `ThemeMode.system`). | Preferencia del usuario; los mockups definen el oscuro, la variante clara se diseña aquí. |
| D3 | **Color por flecha derivado en presentación** desde `ArrowId` (no en el dominio). | Mantiene `domain/` puro — más limpio que la rama bonita, que metió `colorIndex` en la entidad. |
| D4 | **Render e hit-testing agnósticos de la forma** (polilínea desde `arrow.cells` + hit-test por celda). | Habilita flechas dobladas en el futuro sin reescribir la UI. |
| D5 | **Top bar con undo + restart**; victoria sigue siendo **ruta nombrada** (no inline). | Coincide con los mockups y respeta el `AppRouter` actual. |
| D6 | **Copy en español** en todas las pantallas. | Los mockups están en español; hoy la copy está en inglés mezclado. |
| D7 | **Tableros escalados por nivel** vía política de dificultad `LevelBlueprint` (dominio) + generador determinista por nivel. | Replica el comportamiento de la otra rama (tableros crecen y hay más flechas al subir de nivel) con mejor SRP: el generador *genera*, la política *decide dificultad*. |

---

## 4. No-objetivos (fuera de alcance de este pase)

- **Flechas dobladas/conectadas en L** (imágenes "CHALLENGE AWAITS"): requiere evolución de dominio
  + generador. **Habilitado por el diseño pero no implementado aquí** (ver §10).
- **Diseño de niveles hechos a mano** (puzzles curados): la generación sigue siendo *procedural*
  (escalada por nivel, §8). Curar niveles concretos es trabajo futuro.
- Cualquier cambio de backend (`MazePruebaBack/`).
- Sonido, háptica, persistencia adicional de progreso.

---

## 5. Tema y paleta

Se reestructuran `core/theme/app_colors.dart` y `core/theme/app_theme.dart`. **Cambio de modelo de
color:** se eliminan las constantes `arrowUp/Down/Left/Right` (color por dirección) y entra una
**`arrowPalette` de 8 tonos** + helper `arrowColor(int index)`.

### Paleta oscuro (jewel sobre índigo profundo)
| Rol | Hex |
|---|---|
| background / backgroundDeep | `#0E1020` / `#070812` (gradiente radial) |
| surface | `#181B30` |
| pill | `#242843` |
| onSurface | `#E6E8F5` |
| muted | `#7E84A8` |
| seed / primary (CTA) | `#5B6CC4` |
| victory (acento) | `#E0B45A` |
| arrowPalette (8) | `#46B98C` `#39ACBE` `#D56C8E` `#D7A24A` `#C9764E` `#8A6FD0` `#5E7AD0` `#CF646F` |

### Paleta claro (diseñada aquí, coherente con la familia índigo)
| Rol | Hex |
|---|---|
| lightBackground / deep | `#F4F5FB` / `#E7E9F4` (gradiente radial suave) |
| lightSurface | `#FFFFFF` |
| lightPill | `#E7E9F5` |
| lightOnSurface | `#1B1E33` |
| lightMuted | `#6B7095` |
| lightPrimary | `#4B5BB5` |

- La **`arrowPalette` se reutiliza igual en ambos temas** (croma suficiente para leerse sobre blanco
  e índigo; identidad de color consistente al cambiar de tema). Si en claro algún tono queda flojo
  de contraste, se profundiza ~10% en una variante `arrowPaletteLight` (ajuste menor, no rama de diseño).
- Se conservan `glassFill` / `glassBorder` (los usa el selector de niveles).
- `AppTheme.light()/dark()` mantienen su forma (dos `ThemeData`, `ThemeMode.system` en `main.dart`);
  solo cambian los colores que alimentan cada `ColorScheme`.

---

## 6. Render del tablero (agnóstico de la forma)

Reescritura de los 3 archivos de render, adaptados al dominio actual (`Position.row/col`, `ArrowId`,
`ArrowBoard.cols/rows`).

### 6.1 `arrow_painter.dart` — painter por polilínea
- El cuerpo se dibuja como un `Path` que **recorre `arrow.cells`** (centros de celda) con
  `StrokeJoin.round` + `StrokeCap.round`, en **coordenadas locales** del bounding box de la flecha:
  `centroLocal(cell) = ((col - minCol + 0.5) * cell, (row - minRow + 0.5) * cell)`.
- Grosor del cuerpo `≈ 0.40 * cell`. Capas: **glow** (color @30%, `MaskFilter.blur`) por debajo →
  **cuerpo** → **brillo interior** blanco @22% encima.
- **Punta triangular** clara en `cells.last`, orientada por el **último segmento** de la polilínea
  (vector `cells[n-2] → cells[n-1]`). Esto funciona para flechas rectas y dobladas sin depender de
  `direction`/`length`.
- Firma propuesta: `ArrowPainter({ required List<Position> cells, required Color color,
  required double cell, required int minCol, required int minRow })`. El painter mapea cada celda a
  coords locales con `minCol`/`minRow` como origen del bounding box; la orientación de la punta se
  deriva de los dos últimos elementos de `cells` (los nombres exactos se afinan en el plan). La clave
  es que **consume `cells`**, no `length`+`direction` rectos.
- Para flechas rectas el resultado es visualmente idéntico a los mockups; para flechas dobladas,
  funciona sin cambios.

### 6.2 `board_widget.dart` — layout responsive + hit-testing por celda
- Sigue siendo `ConsumerWidget` (presentación → `gameControllerProvider`).
- **Responsive con `LayoutBuilder`:** `cell = min(maxWidth / cols, maxHeight / rows)`. Tablero
  centrado de `cols*cell × rows*cell`. (Reemplaza el `_cellSize = 72` fijo.)
- **Fondo:** panel `surface @30%`, esquinas redondeadas y **rejilla sutil** (`_GridPainter`,
  líneas `muted @10%`) detrás de las flechas. `clipBehavior: Clip.none` para que la flecha saliente
  cruce el borde.
- **Cada flecha en un `Positioned`** con su bounding box vía `_rectFor(arrow, cell)`. Las `ArrowWidget`
  son **render puro** (CustomPaint + shake), **sin gesto propio**.
- **Hit-testing por celda a nivel de tablero (a prueba de forma):** un único `GestureDetector`
  (o `Listener`) sobre el `Stack` con `onTapUp`:
  `col = (localPos.dx / cell).floor()`, `row = (localPos.dy / cell).floor()` (con *clamp* a rango)
  → `ArrowBoard.arrowAt(Position(row: row, col: col))` → si hay flecha, `controller.tapArrow(id)`.
  Esto resuelve **definitivamente** "qué flecha toco" para flechas rectas y dobladas, y elimina
  el solapamiento de *bounding boxes*.
- **Overlay de salida:** cuando `state.exitingArrow != null`, monta `ExitingArrowWidget` en el rect
  de esa flecha (ver §7).

### 6.3 `arrow_widget.dart` — render + shake (sin gesto)
- Pasa de `StatelessWidget` a `StatefulWidget` para alojar el **shake**.
- Ya **no** contiene `GestureDetector` (el gesto vive en el tablero). Opcionalmente `IgnorePointer`
  para que nunca intercepte.
- Recibe `cells` (de los que el painter deriva cuerpo y punta), `color`, `isBlocked`, `blockedNonce`.
- **Se elimina `isHighlighted`** (código muerto; el modelo es tap = acción inmediata, sin selección).

### 6.4 Helper de color (presentación)
- `int arrowColorIndex(ArrowId id)`: deriva un índice **estable** desde `id.value`
  (los ids son `arrow-0`, `arrow-1`…: se parsea el sufijo numérico; *fallback* determinista vía
  `hashCode` si no parsea). Estable al remover flechas (ligado a identidad, no a posición en lista).
- `AppColors.arrowColor(arrowColorIndex(id))` resuelve el tono.

---

## 7. Estado y animaciones (`application/`)

### 7.1 `game_state.dart` — `GamePlaying` extendido con señales transitorias de presentación
```dart
class GamePlaying extends GameState {
  final ArrowBoard board;
  final MoveCount moves;
  final ArrowId? blockedArrow; // última flecha tocada que no puede salir
  final int blockedNonce;      // ++ por bloqueo → re-dispara el shake
  final Arrow? exitingArrow;   // "fantasma" cosmético de la flecha recién removida
  final int exitNonce;         // ++ por salida → re-dispara el slide-out
  final bool canUndo;          // habilita/deshabilita el botón undo del top bar
}
```
Son *hints* de feedback para la UI reactiva (no son reglas de dominio). Viven en `application/state`.

### 7.2 `game_controller.dart`
Guarda el `LevelId` actual; `loadLevel` pasa a usar `LevelBlueprint` para escalar el tablero por
nivel (detalle en §8). Métodos modificados:
- **`tapArrow(id)`** mantiene la validación vía `RemoveArrowUseCase` (timing de Command/undo intacto):
  - **bloqueada** (`Left`): re-emite `GamePlaying` con `blockedArrow=id`, `blockedNonce++`,
    board/moves sin cambio → la flecha hace **shake**.
  - **legal** (`Right`): localiza la flecha con `ArrowBoard.arrowById(id)`, la remueve por Command,
    emite `GamePlaying(newBoard, moves+1, exitingArrow=removida, exitNonce++, canUndo:true)`;
    o `GameWon(moves)` si `newBoard.isCleared`.
- **`undoMove()`**: como hoy, reseteando campos transitorios y recalculando `canUndo`.
- **`restartLevel()`** (nuevo): `invoker.clear()` + regenera el nivel + `moves=0` + transitorios
  limpios. Como la generación es **determinista por nivel** (§8), restart reproduce el **mismo
  tablero** del nivel.

### 7.3 Adiciones menores de soporte
- `CommandInvoker.clear()` (application): `_history.clear()` para el restart.
- `ArrowBoard.arrowAt(Position) → Arrow?` (domain, query pura): para el hit-testing por celda.
- `ArrowBoard.arrowById(ArrowId) → Arrow?` (domain, query pura): para el fantasma de salida del
  controller, sin iterar `arrows` fuera del aggregate root.

### 7.4 Animaciones (presentación)
- **Shake** en `ArrowWidget`: en `didUpdateWidget`, si `isBlocked && blockedNonce` cambió →
  `Transform.translate` con onda sinusoidal amortiguada hacia su dirección (offset por `switch`
  sobre `Direction`, sin tocar el VO).
- **Slide-out** en `ExitingArrowWidget` reescrito: overlay **auto-desmontable, keyed por `exitNonce`**.
  Anima slide (en dirección de la punta) + fade y luego renderiza vacío; el siguiente `exitNonce`
  crea una instancia nueva. Sin métodos extra de "limpiar estado" ni emisiones adicionales.
  Usa el nuevo painter por polilínea.

### 7.5 Timing de victoria
Al remover la última flecha, el estado pasa a `GameWon` directo (flujo actual) y `GameScreen` navega
a la ruta de victoria; el slide-out de la última flecha se omite (la victoria tiene su propia
animación). Diferir la victoria una duración de salida es *polish* opcional, no requerido.

### 7.6 Manejo de errores
`RemoveArrowUseCase` sigue devolviendo `Either`; bloqueada/ausente → `Left` → shake, nunca crash.
Undo sin historial → no-op. Restart siempre seguro.

---

## 8. Generación escalada por nivel

Hoy el bloqueo a tableros grandes **no está en el generador** (que ya acepta `cols/rows/arrowCount`
arbitrarios) sino en `GameController.loadLevel`, que **hardcodea `4×4` con 5 flechas e ignora el
`levelId`**. Se introduce una curva de dificultad y determinismo por nivel, replicando el
comportamiento de `app-agentic-sprint` (tableros que crecen y con más flechas al subir de nivel)
pero con mejor separación de responsabilidades.

### 8.1 `LevelBlueprint` (dominio, puro) — NUEVO
- Value object / factory `LevelBlueprint.forLevel(int level) → (cols, rows, arrowCount)`. Encapsula
  **toda** la curva de dificultad en un único lugar testeable, sin Flutter ni infraestructura.
- Curva inicial propuesta (tablero cuadrado; **ajustable en el plan**):
  `size = (4 + (level - 1) ~/ 2).clamp(4, 9)` → crece de 4 a 9;
  `arrowCount = ((size * size * 0.5) / 3).round().clamp(4, size * size)` → densidad ~50 % con largo
  medio ~3 ⇒ crece ~5 → ~13. (`cols = rows = size`.)
- Decisión (D7): la curva vive aquí, **no dentro del generador** (SRP/OCP). Si mañana los niveles los
  sirve el backend, se sustituye la fuente del blueprint sin tocar el generador.

### 8.2 `level_id.dart` (VO) — helper numérico
- Se añade `int get number => int.tryParse(value) ?? 1;` para obtener el nivel numérico sin cambiar el
  tipo `String` ni romper rutas/selector. Centraliza el parseo (lo usan §9.3 "siguiente nivel" y el
  controller).

### 8.3 `ILevelGenerator` + `GraphBoardGenerator` — determinismo y robustez
- El puerto pasa a `ArrowBoard generate({required int cols, required int rows, required int arrowCount, int? seed})`.
- **Determinista por nivel:** el controller pasa `seed = levelId.number` ⇒ `Random(seed)`. Mismo nivel
  = mismo puzzle (correcto en un juego de niveles) y restart reproduce el tablero idéntico (§7.2).
- **Longitud mínima de flecha = 2** (hoy permite 1 celda, que se ve como punto): `length` en
  `2..maxLen` con `maxLen = min(4, (eje aplicable) ~/ 2)` y guardas de factibilidad para tableros chicos.
- **`maxAttempts` escalado** con el tamaño (p. ej. `cols * rows * 30`) en vez del `500` fijo, para que
  tableros grandes logren colocar las flechas objetivo.
- Si aun así no coloca todas las flechas pedidas, **degrada con gracia** (coloca las que pueda) y lo
  registra vía el logger AOP.

### 8.4 `game_controller.dart` — `loadLevel`
```dart
final bp = LevelBlueprint.forLevel(levelId.number);
final board = _generator.generate(
  cols: bp.cols, rows: bp.rows, arrowCount: bp.arrowCount, seed: levelId.number,
);
```
Adiós al `4×4×5` fijo. El render ya es responsive e hit-testing por celda (§6), así que tableros
hasta 9×9 (o más) entran **sin cambios de UI**.

---

## 9. Pantallas y navegación

Se conserva `AppRouter` con **rutas nombradas** (no se adopta el `MaterialPageRoute` de la otra rama).
Toda la copy pasa a **español**.

### 9.1 `home_screen.dart` (mockup home)
- Fondo `RadialGradient` (oscuro `background→backgroundDeep`; claro su equivalente).
- **Logo animado** `_LogoArrows` (privado, `StatefulWidget`): clúster de 3 barras redondeadas con
  iconos de flecha en tonos de `arrowPalette`, flotación perpetua sutil (bob senoidal).
- Título **"ARROW MAZE"** (`displaySmall`, w900, `letterSpacing 2`), tagline
  **"Despeja el tablero. Saca cada flecha."** (muted), botón **"JUGAR"** (`FilledButton` seed,
  radio 18, w800) → `AppRouter.levelSelection`.

### 9.2 `game_screen.dart` (mockup tablero)
- Sigue siendo `ConsumerStatefulWidget` con `loadLevel` en `initState` (post-frame actual) y
  `ref.listen` → en `GameWon` navega a la ruta de victoria.
- Reemplaza el `AppBar` por un **top bar custom**: botón **atrás** circular (`Navigator.pop`),
  **píldora de nivel** central con `levelId.value`, y a la derecha **undo** circular
  (habilitado por `state.canUndo` → `undoMove`) + **restart** circular (→ `restartLevel`).
- Cuerpo: `Expanded(Center(BoardWidget))` con padding. `_CircleButton` y la píldora como widgets
  privados.
- **AnimatedSwitcher** ligero (fade + scale 0.96→1) entre `loading`/`playing`.

### 9.3 `victory_screen.dart` (won view, como ruta)
- Fondo gradiente, **trofeo elástico** (`TweenAnimationBuilder`, `Curves.elasticOut`, color `victory`),
  **"¡Tablero limpio!"**, subtítulo **"Nivel X · N movimientos"** (muted).
- Botones: **"Siguiente nivel"** (→ ruta game con `LevelId` siguiente), **"Reintentar"**
  (→ ruta game con el mismo `LevelId`, que regenera), **"Volver a niveles"** (→ `levelSelection`
  limpiando la pila).
- La **ruta de victoria pasa a recibir `levelId` + `moves`** (hoy solo `moves`): se actualiza la
  llamada en `GameScreen` y el parseo en `AppRouter`. `LevelId` es `String` ("1","2"…); siguiente =
  `(int.parse + 1).toString()` con *fallback* si no es numérico.

### 9.4 `level_selection_screen.dart` (no está en los mockups)
- **Solo re-tematizado** a la paleta nueva: fondo gradiente, chips de nivel tipo píldora
  (`pill`/`surface`), copy "Niveles". Sin rediseño estructural.

### 9.5 `app_router.dart`
- Único cambio: argumentos de la ruta de victoria (`levelId` + `moves`). El grafo de navegación
  (home → niveles → game → victoria) queda intacto.

---

## 10. Extensibilidad: flechas dobladas (futuro, habilitado)

El diseño **no se cierra** a flechas dobladas/conectadas en L:

- **Seam de presentación:** painter y board widget dependen **solo de `arrow.cells` y la orientación
  de la punta** (ambos ya existen en `Arrow`). El hit-testing es por celda (`arrowAt`), no por forma.
  Por tanto, una flecha doblada se renderiza y se toca correctamente **sin cambiar la UI**.
- **Trabajo futuro (rol `domain-modeler`, NO en este pase):** evolucionar la entidad `Arrow` de
  `(tail, direction, length)` a un **path explícito de celdas** (polilínea con dirección de punta
  final) y enseñar al `GraphBoardGenerator` a producir caminos con giros, manteniendo el invariante
  de resolubilidad (DAG). El `exitPath` y `canExit` del dominio deberán considerar la nueva geometría.
- Resultado: "flechas dobladas" pasa de *bloqueado* a **fuera de alcance pero habilitado**.

---

## 11. Estrategia de pruebas (AAA, mocks para aislar)

Hoy no hay tests en el front; se añaden para la lógica nueva/cambiada.

- **`GameController`** (unidad crítica) — mockeando `ILevelGenerator` y `RemoveArrowUseCase`
  (para forzar `Left`/`Right`), invoker real:
  - `loadLevel` → `GamePlaying` con el board del generador y `moves 0`; verifica que llama a
    `generate` con las dimensiones del `LevelBlueprint` del nivel y `seed = levelId.number`.
  - `tapArrow` bloqueada → `blockedArrow` seteada, `blockedNonce++`, board/moves sin cambio;
    dos toques seguidos → `blockedNonce` sube cada vez.
  - `tapArrow` legal → flecha removida, `moves+1`, `exitingArrow`=removida, `exitNonce++`,
    `canUndo:true`.
  - `tapArrow` que limpia el tablero → `GameWon`.
  - `undoMove` → restaura board, `moves-1`, `canUndo` recalculado.
  - `restartLevel` → invoker limpio (`canUndo:false`), board fresco, `moves 0`.
- **`CommandInvoker.clear()`** → tras `clear`, `canUndo == false`.
- **`ArrowBoard.arrowAt()` / `arrowById()`** → flecha correcta por celda/id; `null` si ausente o
  celda vacía.
- **Helper `arrowColorIndex(ArrowId)`** → mapeo estable y en rango (`arrow-0`→0, `arrow-8`→0 mód 8;
  *fallback* determinista).
- **`LevelBlueprint.forLevel`** → curva monótona no decreciente en `size`/`arrowCount`, *clamp* en los
  extremos (nivel 1 → mínimo; nivel alto → tope 9×9), `LevelId.number` parsea con *fallback* 1.
- **`GraphBoardGenerator`** → determinismo (mismo `seed` ⇒ tablero idéntico; *seeds* distintos ⇒
  distinto); escalado (tablero mayor coloca más flechas); ninguna flecha de longitud 1; todas las
  flechas colocadas son resolubles (invariante DAG).
- **Widget test de hit-testing (regresión del bug):** montar `BoardWidget` con varias flechas,
  tocar dentro de la huella de una y verificar que `tapArrow` se invoca con **ese** `ArrowId`;
  tocar una celda vacía no invoca nada.
- Painters: sin tests unitarios (visual); a lo sumo smoke de `shouldRepaint`.

Infra: `flutter_test` + `mockito`/`build_runner` (ya en el stack) con `@GenerateMocks` para los puertos.

---

## 12. Resumen de archivos

### Modificados (18)
| Archivo | Cambio |
|---|---|
| `core/theme/app_colors.dart` | Paleta jewel, `arrowPalette` + `arrowColor()`, `pill`/`backgroundDeep`, variantes claras. Elimina `arrowUp/Down/Left/Right`. |
| `core/theme/app_theme.dart` | Alimenta los `ColorScheme` con los nuevos colores (misma estructura). |
| `presentation/game/painters/arrow_painter.dart` | Reescritura: polilínea desde `cells`, coords locales, cuerpo grueso + glow + punta. |
| `presentation/game/widgets/arrow_widget.dart` | `StatefulWidget`, render puro (sin gesto), shake por `blockedNonce`. Sin `isHighlighted`. |
| `presentation/game/widgets/board_widget.dart` | `LayoutBuilder`, rejilla, `Positioned` por bbox, hit-testing por celda, overlay de salida. |
| `presentation/game/widgets/exiting_arrow_widget.dart` | Reescritura: auto-desmontable, keyed por `exitNonce`, nuevo painter. |
| `presentation/home/screens/home_screen.dart` | Rediseño + logo animado + copy español. |
| `presentation/game/screens/game_screen.dart` | Top bar custom, AnimatedSwitcher, cableado restart. |
| `presentation/level_selection/victory_screen.dart` | Rediseño (trofeo elástico, botones), recibe `levelId`+`moves`. |
| `presentation/level_selection/level_selection_screen.dart` | Re-tematizado + copy español. |
| `core/router/app_router.dart` | Args de la ruta de victoria (`levelId`+`moves`). |
| `application/state/game_state.dart` | `GamePlaying` con campos transitorios. |
| `application/state/game_controller.dart` | Guarda nivel; `loadLevel` usa `LevelBlueprint`+`seed`; `tapArrow` con feedback; `restartLevel`; `canUndo`. |
| `application/commands/command_invoker.dart` | `clear()`. |
| `domain/arrows/entities/arrow_board.dart` | `arrowAt(Position)` y `arrowById(ArrowId)` (queries puras). |
| `domain/arrows/services/i_level_generator.dart` | Puerto: `generate({cols, rows, arrowCount, int? seed})`. |
| `infrastructure/generators/graph_board_generator.dart` | `seed` por nivel (determinista); longitud mín. 2; `maxAttempts` escalado; degradación con gracia logueada. |
| `domain/board/value_objects/level_id.dart` | `int get number` (parse con *fallback* 1). |

### Nuevos
- `domain/board/value_objects/level_blueprint.dart` — política de dificultad `LevelBlueprint.forLevel`.
- 1 helper de color en presentación (p. ej. `presentation/game/arrow_color.dart`).
- Tests: `test/application/game_controller_test.dart` (+ `.mocks.dart`),
  `test/application/command_invoker_test.dart`, `test/domain/arrow_board_test.dart`,
  `test/domain/level_blueprint_test.dart`, `test/infrastructure/graph_board_generator_test.dart`,
  `test/presentation/board_widget_hit_test.dart`, `test/presentation/arrow_color_test.dart`.

---

## 13. Proceso (CLAUDE.md)

- El plan de implementación secuenciará el trabajo **por fragmentos**.
- Cada fragmento significativo → entrada en `MazePruebaFront/AI_HISTORY.MD` + commit
  **Conventional Commits** (p. ej. `refactor(front): rewrite ArrowPainter as cell polyline`,
  `feat(front): cell-based board hit-testing`, `test(front): add GameController feedback tests`).
- Actualizar `MazePruebaFront/README.md` si cambia superficie pública (arquitectura, mecánica).
- No acumular múltiples fragmentos en un solo commit.

---

## 14. Riesgos y trade-offs

| Riesgo | Mitigación |
|---|---|
| El hit-testing por celda cambia el patrón (gesto sube al tablero). | Es más robusto y simple que N detectores; cubierto por widget test de regresión. |
| Campos transitorios en `GamePlaying` mezclan feedback de UI con estado de juego. | Son *hints* de presentación bien acotados; alternativa (providers efímeros) añade complejidad sin beneficio claro. |
| La variante clara de la paleta no está validada visualmente (no hay mockup). | `arrowPalette` compartida; ajuste de contraste menor reservado (`arrowPaletteLight`). |
| En tableros grandes el generador puede no colocar todas las flechas objetivo dentro de `maxAttempts`. | `maxAttempts` escalado con el tamaño + degradación con gracia (coloca las que pueda) logueada; la curva del `LevelBlueprint` es conservadora (~50 % densidad) y ajustable. |
| La curva de dificultad inicial puede no sentirse bien balanceada. | Está aislada en `LevelBlueprint.forLevel` (un solo punto), con tests; se afina sin tocar generador ni UI. |
| Último slide-out se omite al ganar. | Aceptado; la pantalla de victoria aporta el momento de recompensa. |
