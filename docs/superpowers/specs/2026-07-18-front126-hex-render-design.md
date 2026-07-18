# front#126 — Render hexagonal (capa de presentación)

**Fecha:** 2026-07-18
**Issue:** [front#126](https://github.com/DanCas03/MazePruebaFront/issues/126) — `feat(presentation): render hexagonal — superficie, proyección de 6 direcciones y hit-testing`
**Rama:** `feat/#126-hex-render` (sobre `feat/#125-hex-decoder-mount`, PR #129 aún sin mergear)
**ADR:** [ADR-0007](../../../../docs/adr/0007-hexagonal-mode.md) — modo hexagonal flat-top, `Direction` a 8, descriptor de geometría en el wire.

> Este documento es el **entregable del `superpowers:brainstorming`** que exige el brief del issue.
> Es la **entrada** de la sesión obligatoria de `/grilling` + `/domain-modeling` sobre el brief, que
> afina el detalle fino explícitamente diferido (painter nuevo vs bifurcación interna). El plan de
> ejecución se produce después con `superpowers:writing-plans`.

## Contexto

El módulo hexagonal ya tiene lista su cadena de dominio e infraestructura (front#124/#125): `HexSpace`
y `HexMaskedSpace` existen como subclases puras de `BoardSpace`, `Direction` tiene sus 8 valores, el
descriptor `space` del wire se decodifica al `BoardSpace` correcto, y el montaje polimórfico
(`_mountedBoard` → `space.masked(active)`) ya entrega un `HexMaskedSpace` a la vista sin ningún switch
de tipo. `BoardView` ya pasa cualquier `BoardSpace` — incluido `HexMaskedSpace` — a `BoardSurfacePainter`.

Lo que falta es **puramente presentación**. Cuatro superficies de la capa de presentación asumen hoy
celdas cuadradas y recalculan, cada una por su cuenta, el centro de celda rectangular
`(col - minCol + 0.5)·cell`:

1. **`BoardSurfacePainter`** (`lib/presentation/game/painters/board_surface_painter.dart`) — dibuja
   rectángulos y aristas horizontales/verticales; deriva el layout del bounding box del espacio.
2. **Proyección de direcciones** (`lib/presentation/game/direction_projection.dart`) — `directionUnit`
   y `directionAngle` **ya tienen** los 8 valores con geometría flat-top; pero `cellsToEdge` lanza
   `UnimplementedError` en las 4 diagonales (con nota: "se resuelve en el render hexagonal front#126").
3. **Hit-testing** (`lib/presentation/game/widgets/board_widget.dart`, `onTapUp`) — parte el tap por
   columnas/filas con `floor(dx/cell)`.
4. **Flecha y salida** (`arrow_painter.dart`, `snake_exit_painter.dart` / `exiting_arrow_widget.dart`)
   — centros de celda `(col+0.5)·cell` y carril de salida vía `cellsToEdge` sobre la caja `cols×rows`.

La geometría de **dominio** hex ya es correcta: `HexSpace` usa coordenadas axiales `(q,r)` mapeadas a
`Position(row, col)` con `col = q + R`, `row = r + R`; `directions` devuelve las 6 direcciones hex;
`contains` aplica la restricción cúbica; `step` es el único intérprete de los 6 deltas axiales; y
`BoardSpace.exitLane(head, dir)` camina `step` hasta la frontera — correcto también para masked/hex.

## Decisiones de forma (cerradas en el brainstorming)

### D1 — Seam polimórfico `BoardGeometry`

Se introduce una abstracción de presentación que centraliza toda la aritmética celda↔píxel que hoy las
cuatro superficies inlinean por separado. Selección de implementación en un **único** punto factory
(el único `is HexSpace` de la capa de presentación; la geometría no puede vivir en dominio porque
`domain/` es Dart puro sin `Offset`/`Path`).

```dart
abstract class BoardGeometry {
  factory BoardGeometry.forSpace(BoardSpace s, BoxConstraints c) =>
      s is HexSpace ? HexGeometry(s, c) : RectGeometry(s, c);

  Size get size;                                 // tamaño del tablero, fit a la banda 9:16
  Offset centerOf(Position p);                   // centro de celda en píxeles
  Position? cellAt(Offset px);                   // hit-test: null = fuera del tablero o celda masked
  Path cellPath(Position p);                     // rect → Rect · hex → hexágono flat-top
  bool sharedEdge(Position cell, Direction side);// hay arista sólo si el vecino de ese lado existe
  List<Position> exitLane(Position head, Direction dir);
}
```

- **`RectGeometry`** extrae los formularios rectangulares actuales *verbatim*: `centerOf` =
  `(col - minCol + 0.5)·cell` y `(row - minRow + 0.5)·cell`; `cellAt` = `floor(dx/cell)` con clamp a
  bounds; `cellPath` = `Rect.fromLTWH(...)`; `size` = `min(maxW/cols, maxH/rows)` × `cols/rows`;
  `exitLane` envuelve `cellsToEdge`. **Byte-idéntico por construcción.** El candado son los tests de
  caracterización existentes (canvas-matchers), que no deben cambiar.
- **`HexGeometry`** flat-top: circunradio de celda `s` derivado de `size`/bounds para que el tablero
  R=5 quepa completo en la banda 9:16; `centerOf` con `x = 1.5·s·q`, `y = √3·s·(r + q/2)` (más el
  origen de encuadre); `cellAt` con redondeo cúbico/axial estándar seguido del gate `space.contains`;
  `cellPath` = polígono de 6 vértices flat-top; `exitLane` delega en `space.exitLane` (dominio, ya
  correcto).

`board_widget.build` construye **una** `BoardGeometry` desde `space` + `constraints` y la inyecta a las
cuatro superficies en lugar del `double cell` crudo.

### D2 — Carril de salida: hex por `exitLane` real, rect intacto

`HexGeometry.exitLane` delega en `space.exitLane` — respeta la frontera masked y las diagonales.
`RectGeometry.exitLane` sigue usando `cellsToEdge` tal cual, con el mismo resultado que hoy (byte-a-byte),
**incluido** el bug documentado en `board_widget.dart:224-227` (en masked rect la salida cruza celdas
ausentes hasta el borde de la caja). Ese bug **no** se corrige aquí: se registra como issue de deuda
separado para no arriesgar la invariante byte-a-byte. `cellsToEdge` deja de invocarse en diagonales
(el hex ya no lo usa); su `UnimplementedError` diagonal queda como guard defensivo del camino rect.

## Componentes y flujo

### Painter de superficie
El camino rectangular conserva **intactas** sus dos estrategias actuales: `_paintFullPanel` (un único
`RRect` con `Radius.circular(cell·0.35)` + grid H/V) y `_paintMaskedCells` (relleno por celda + aristas
interiores). Se añade una estrategia hex: por cada celda existente, rellena `geometry.cellPath` (el
hexágono) y dibuja cada una de las 6 aristas **sólo si el vecino de ese lado existe**
(`geometry.sharedEdge`) — la misma regla del enmascarado de hoy, ahora sobre 6 lados; una arista con
celda ausente al otro lado es frontera visual. El color de superficie sigue siendo uniforme.

**Temático-hex:** el color por `paintRole` vive en las **flechas**, no en la superficie. El
`ThemedArrowColorResolver` existente (`arrow_color_resolver.dart`) ya resuelve `arrow.paintRole` contra
`state.palette` y es agnóstico del espacio, así que el temático-hex enmascarado colorea igual que los
temáticos rectangulares de hoy sin tocar el resolver.

La decisión fina **painter nuevo (`HexBoardSurfacePainter`) vs bifurcación interna** en
`BoardSurfacePainter` se cierra en el `/grilling`; ambas consumen el mismo `BoardGeometry`.

### Hit-testing
`onTapUp` reemplaza el `floor(dx/cell)` por `geometry.cellAt(details.localPosition)`. `null` ⇒ no
selecciona nada. `HexGeometry.cellAt` pliega dentro el gate de fuera-del-hexágono y de celda masked, de
modo que el `space.contains` explícito del widget se vuelve redundante (se mantiene o se elimina según
el resultado de las pruebas, sin cambiar comportamiento rect).

### Flecha y animación de salida
`ArrowPainter._center` pasa a `geometry.centerOf`: el polyline del cuerpo multi-celda sigue
automáticamente los centros hex; la cabeza se rota con `directionAngle(headDirection)` (ya tiene los 8
valores, sin aritmética propia — ADR-0005 D4). `SnakeExitPainter` recorre `geometry.exitLane` y extiende
la trayectoria con pasos `directionUnit(headDirection)` en píxeles; en hex usa el carril real del
espacio, en rect se comporta igual que hoy. `ExitingArrowWidget` recibe la `BoardGeometry` en lugar de
`cols/rows`.

### Proyección de direcciones
`directionUnit` y `directionAngle` no cambian (ya son flat-top-correctos para los 8 valores). El uso de
`cellsToEdge` queda encapsulado tras `RectGeometry.exitLane`.

## Pruebas (AAA)

El repositorio **no** usa image-goldens (`matchesGoldenFile` no aparece en la suite); los tests de
painter usan los canvas-matchers de Flutter (`paints`, `paintsExactlyCountTimes`). Los tests hex siguen
ese mismo patrón:

- **`HexGeometry`:** `centerOf` de coordenadas `q/r` conocidas devuelve el píxel esperado; `cellAt` de
  centros y de puntos cerca del borde de las celdas de un R=3 mapea a la celda correcta; las esquinas
  del bounding box (fuera del hexágono) devuelven `null`; una celda masked devuelve `null`.
- **Proyección:** los 6 vectores unidad y sus 6 ángulos coinciden con la geometría flat-top declarada.
- **Painter hex:** R=2 completo (cuenta de hexágonos dibujados = `cellCount(2) = 19` y de aristas
  compartidas) y un caso enmascarado con frontera interior (celda ausente excluida, aristas de frontera
  correctas).
- **Salida:** una flecha diagonal en un tablero hex sale por la frontera correcta (test de widget o de
  caracterización), usando el `exitLane` real.
- **Regresión:** ningún test de painter/board/flecha/salida rectangular existente cambia; suite completa
  verde.

Cada fragmento significativo se registra en `AI_HISTORY.MD` y se commitea por separado (Conventional
Commits), como exige el proyecto.

## Fuera de alcance

- Pantalla de selección del modo hex (home, ruta `/hex`, fichas) — es front#127.
- Tema/paleta visual propios del modo hex — paleta estándar de campaña; los temáticos usan su `palette`
  del wire.
- Tutorial/onboarding de las 6 direcciones.
- **Corrección del bug de salida en masked rect** — deuda separada; se abre issue propio.

## Riesgos

- **Invariante byte-a-byte del camino rect.** La extracción de `RectGeometry` debe reproducir los
  offsets exactos. Mitigación: `board_surface_painter_test` (1 `rrect` + 6 `drawLine` en caja llena;
  8 `drawRect` + 8 `drawLine` en masked), más los tests de `arrow_painter`, `snake_exit_painter`,
  `board_widget`/`board_view_*` y `exiting_arrow_widget`, actúan de candado. Cualquier drift falla un
  test y se corrige en `RectGeometry`.
- **Encuadre 9:16 en R grandes.** `HexGeometry.size` debe garantizar que R=5 entra completo; se cubre
  con un test de dimensiones sobre los radios de contenido (R=3/4/5 de back#60).
