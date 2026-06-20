# Diseño — Flechas dobladas, tablero vertical denso y mayor población

**Fecha:** 2026-06-20
**Artefacto:** `MazePruebaFront/` (frontend Flutter)
**Estado:** Aprobado para planificación

---

## 1. Contexto y objetivo

El siguiente paso del juego es enriquecer el tablero en tres ejes pedidos por el equipo:

1. **Tableros más grandes** y de proporción vertical (como móvil).
2. **Flechas que doblan** en varias direcciones (caminos serpenteantes), no solo rectas.
3. **Tablero más poblado** de flechas.

La buena noticia tras explorar el código es que la base ya está preparada para formas no rectas:

- `ArrowPainter` ya dibuja una **polilínea** sobre `arrow.cells` con punta triangular → soporta curvas visualmente.
- El hit-testing en `BoardWidget` ya es **por celda** (`board.arrowAt(pos)` → `cells.contains`) → agnóstico a la forma.
- `ArrowBoard.canExit` / `Arrow.exitPath` ya razonan sobre el **rayo recto desde la cabeza** hasta el borde.

Lo que falta es el **modelo de dominio** (la flecha es recta hoy: `tail` + `direction` + `length`), el **generador** (produce solo rectas) y la **animación de salida** para una flecha doblada.

## 2. Decisiones tomadas (brainstorming)

| Decisión | Elección | Consecuencia |
|---|---|---|
| **Mecánica de salida de una flecha doblada** | **Serpiente (cabeza primero)**: sale de cabeza y el cuerpo se retrae por su propio camino. | La condición de salida es **idéntica a hoy**: el carril recto desde la cabeza al borde (en `headDirection`) debe estar libre de otras flechas. El cuerpo retrae sobre celdas que ya ocupaba → nunca colisiona consigo mismo. `canExit`/`exitPath` se conservan casi tal cual; se preservan solubilidad por construcción y undo. |
| **Forma/tamaño/densidad del tablero** | **Vertical denso** (como la imagen de referencia): crece ~6×8 → ~11×15, relleno ~65-70%, caminos de hasta ~8-12 celdas. | Solo cambia `LevelBlueprint`. Proporción vertical encaja en pantalla de móvil. |
| **Animación de salida** | **Slither real**: painter dedicado que retrae el cuerpo siguiendo la trayectoria (cuerpo + carril). | Única pieza realmente nueva. ~50-80 líneas aisladas en un `SnakeExitPainter` + control de animación. |

## 3. Enfoque elegido (y alternativas descartadas)

**Elegido: generalizar `Arrow` de "recta" a "camino"** (`List<Position>` + `headDirection`). Una flecha recta es un caso degenerado del camino. Reutiliza painter, hit-testing y condición de salida.

Descartadas:
- **Subtipo `BentArrow` (polimorfismo):** añade tipos y duplica lógica; el painter ya unifica por `cells`, así que no aporta valor. Viola YAGNI.
- **Descripción turtle (`tail` + lista de segmentos):** todos los consumidores necesitan `cells` igualmente; recalcularlas es más código que guardar el camino directo.

## 4. Diseño detallado

### 4.1 Dominio — `Arrow` como camino

```dart
class Arrow extends Equatable {
  final ArrowId id;
  final List<Position> cells;   // cola (first) → cabeza (last); orto-adyacentes, sin repetir
  final Direction headDirection; // dirección por la que la cabeza sale del tablero

  Position get head => cells.last;
  Position get tail => cells.first;
  Direction get direction => headDirection; // getter de compatibilidad (widgets/animaciones)
  int get length => cells.length;

  /// Celdas libres que debe recorrer la cabeza para salir (rayo recto al borde).
  List<Position> exitPath(int cols, int rows); // desde head, en headDirection, hasta el borde
}
```

- **Invariantes:** celdas consecutivas ortogonalmente adyacentes y distintas (camino auto-evitante); `length >= 2`; el carril recto desde la cabeza en `headDirection` no intersecta el propio cuerpo (lo garantiza el generador, §4.2).
- **`ArrowLength`** se retira: la longitud es `cells.length`. La validación `>= 2` pasa al constructor de `Arrow` y/o al generador. Se elimina el VO y su test asociado.
- **`ArrowBoard` no cambia:** `arrowAt`, `overlaps`, `canExit`, `exitPath`, `removeArrow` ya operan sobre `cells`. (`overlaps` ya fue añadido en el WIP actual.)
- **LSP intacto:** toda flecha sigue siendo sustituible; es un cambio de representación de la entidad núcleo, no una jerarquía nueva.

### 4.2 Generador — caminata aleatoria auto-evitante (cabeza primero)

Se reescribe **solo** `_randomArrow`. El bucle principal de `GraphBoardGenerator.generate` **no cambia**: sigue colocando una candidata solo si `!overlaps && canExit`, lo que preserva:

- **Solubilidad por construcción (DAG):** cada flecha puede salir en el momento de colocarse dadas las anteriores ⇒ removerlas en **orden inverso de colocación** siempre resuelve. La mecánica serpiente no altera esto: la salida solo depende del carril de la cabeza vs. otras flechas.
- **Determinismo por `seed`** (mismo nivel ⇒ mismo tablero ⇒ restart reproducible).
- **Degradación con gracia** (si no caben todas, devuelve las colocadas y lo registra vía logger AOP).

Nuevo `_randomBentArrow(rng, cols, rows, index, maxPathLen)`:

1. Elige `headDirection` y una **celda-cabeza** cuyo carril recto al borde (en `headDirection`) esté libre de otras flechas.
2. **Reserva** ese carril como prohibido para el cuerpo (la flecha nunca bloquea su propia salida ⇒ se cumple la invariante de §4.1).
3. Crece el cuerpo **hacia atrás** desde la cabeza: longitud objetivo `2..maxPathLen`. En cada paso elige una celda ortogonalmente adyacente que esté en rango, no repita celda del propio cuerpo, no pise otra flecha y no entre al carril reservado. Sesgo anti-reversa (preferir girar/seguir) para fomentar curvas. Si se atasca, acepta el cuerpo más corto siempre que `length >= 2`.
4. Devuelve `Arrow(cells: [...cola → cabeza], headDirection: dir)`.

### 4.3 Curva de dificultad — `LevelBlueprint` vertical denso

```dart
factory LevelBlueprint.forLevel(int level) {
  final lvl = level < 1 ? 1 : level;
  final width  = (6 + (lvl - 1) ~/ 3).clamp(6, 11);
  final height = (8 + (lvl - 1) ~/ 2).clamp(8, 15);
  final maxPathLen = (3 + (lvl - 1) ~/ 2).clamp(3, 12);
  final avgPathLen = (2 + maxPathLen) / 2;
  final arrowCount = (width * height * 0.68 / avgPathLen)
      .round()
      .clamp(4, width * height);
  return LevelBlueprint(cols: width, rows: height, arrowCount: arrowCount, maxPathLen: maxPathLen);
}
```

- Se añade el campo **`maxPathLen`** al blueprint y se pasa como **parámetro explícito** de `ILevelGenerator.generate(...)` (coherente con `cols`/`rows`/`arrowCount`, que ya se pasan individualmente desde el blueprint en `GameController.loadLevel`).
- Números aproximados; el ajuste fino (densidad real lograda, tasa de degradación) se valida en el plan con tableros generados de muestra.
- Toda la dificultad sigue concentrada en un único lugar testeable; el generador solo genera.

### 4.4 Presentación — punta orientada por `headDirection`

`ArrowPainter` recibe `headDirection` para orientar la punta triangular (en lugar de derivarla del último segmento). Así, si el cuerpo gira **justo en la cabeza**, la punta sigue apuntando hacia donde la flecha sale. `ArrowWidget` y `BoardWidget` propagan `arrow.headDirection`. El cuerpo (polilínea) sigue dibujándose desde `cells` sin cambios.

### 4.5 Animación de salida — `SnakeExitPainter` (slither real)

Sustituye la traslación rígida de `ExitingArrowWidget` por una retracción real:

- **Trayectoria** = centros del cuerpo (cola → cabeza) concatenados con el **carril de salida** (cabeza → borde y un margen más allá).
- A tiempo `t ∈ [0,1]`, se desplaza un offset de arco `s = t · total` (donde `total = longitud_cuerpo + longitud_carril + margen`). La flecha renderizada es la sub-polilínea de la trayectoria en el rango de arco `[s, s + longitud_cuerpo]`; los puntos cuyo arco supera la trayectoria quedan fuera (ya salieron por el borde).
- Se dibuja con el mismo estilo grueso (glow + cuerpo + brillo) y la punta orientada por `headDirection` en el extremo delantero.
- El overlay sigue viviendo en el `Stack` con `Clip.none` de `BoardWidget`, así la flecha cruza el borde sin recortarse. `travel`/`nonce` se mantienen como mecanismo de re-animación por `exitNonce`.

### 4.6 Manejo de errores y estado (sin cambios)

- `RemoveArrowUseCase` ya distingue **ausente** (`ArrowNotFoundException`) de **bloqueada** (`InvalidMoveException`).
- `GameController` ya orquesta el fantasma de salida (`exitingArrow` + `exitNonce`), el shake de bloqueo (`blockedNonce`), undo por `CommandInvoker` y restart determinista. No requiere cambios de lógica (solo se beneficia del nuevo painter de salida).

## 5. Pruebas (AAA, aislamiento con mocks)

- **`Arrow`**: `head`/`tail`/`direction`/`length`/`exitPath` sobre caminos doblados (incluyendo curva en la cabeza); invariante de auto-evitación.
- **`GraphBoardGenerator`**: solubilidad por orden inverso de colocación; sin solapes entre flechas; cuerpos auto-evitantes y dentro de rango; carril de cabeza libre al colocar; **determinismo** (mismo seed ⇒ mismo tablero); degradación con gracia cuando el tablero denso no admite todas.
- **`LevelBlueprint`**: curva vertical-densa, clamps de `width`/`height`/`maxPathLen`, `arrowCount` coherente.
- **`ArrowPainter`**: orientación de la punta por `headDirection` (al menos prueba de no-regresión del cálculo de ángulo).
- Mockear dependencias externas (logger) para aislar la unidad bajo prueba.

## 6. Alcance afectado (archivos)

| Archivo | Cambio |
|---|---|
| `domain/arrows/entities/arrow.dart` | Reescritura a modelo de camino (`cells` + `headDirection`, getters de compat). |
| `domain/arrows/value_objects/arrow_length.dart` | **Se retira** (longitud = `cells.length`). |
| `domain/arrows/entities/arrow_board.dart` | Sin cambios (ya opera sobre `cells`; `overlaps` ya presente en WIP). |
| `domain/arrows/services/i_level_generator.dart` | `generate(...)` recibe `maxPathLen` como parámetro explícito. |
| `domain/board/value_objects/level_blueprint.dart` | Curva vertical-densa + campo `maxPathLen`. |
| `infrastructure/generators/graph_board_generator.dart` | `_randomArrow` → caminata auto-evitante cabeza-primero. |
| `presentation/game/painters/arrow_painter.dart` | Punta orientada por `headDirection`. |
| `presentation/game/widgets/arrow_widget.dart` | Propaga `headDirection` (cambio menor). |
| `presentation/game/widgets/board_widget.dart` | Propaga `headDirection`; revisar `travel` para slither (cambio menor). |
| `presentation/game/widgets/exiting_arrow_widget.dart` | Retracción serpiente con `SnakeExitPainter`. |
| Tests correspondientes | Nuevos/actualizados (AAA). |

## 7. Obligaciones de proceso (CLAUDE.md)

- Registrar cada fragmento significativo en `AI_HISTORY.MD`.
- **Commits por fragmento** (Conventional Commits), sin acumular varios fragmentos en un commit.
- Actualizar `MazePruebaFront/README.md` cuando cambie comportamiento público (cambia: el juego ahora tiene flechas dobladas y tablero vertical denso).
- Respetar la dirección de dependencias: `domain/` Dart puro; `presentation/` consume solo `application/`.

## 8. Fuera de alcance (YAGNI)

- Cambios de backend (`MazePruebaBack/`): esta feature es solo frontend.
- Nuevos tipos de celda/obstáculos, multi-cabeza, o flechas que se cruzan.
- Editor de niveles o niveles hechos a mano (la generación sigue siendo procedimental y sembrada).
- El WIP no relacionado en el árbol (prevención de solapamiento ya integrada como base, y rediseño de la home) no forma parte de este spec.

## 9. Preguntas abiertas

Ninguna. Las tres decisiones de diseño (mecánica, tablero, animación) están cerradas.
