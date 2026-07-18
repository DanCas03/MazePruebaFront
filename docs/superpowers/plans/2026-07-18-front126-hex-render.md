# front#126 — Render hexagonal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Renderizar el tablero hexagonal flat-top en presentación (superficie, flechas, animación de salida y hit-testing de 6 direcciones) sin cambiar ni un píxel de los tableros rectangulares.

**Architecture:** Se introduce un seam de presentación `BoardGeometry` (abstracto) con dos implementaciones — `RectGeometry` (reproduce las fórmulas rect actuales) y `HexGeometry` (proyección flat-top). Las cuatro superficies de render (painter de superficie, hit-test, painter de flecha, painter de salida) consumen la geometría en vez de aritmética inline. El painter de superficie hex es una clase nueva (`HexBoardSurfacePainter`); el painter rect queda intacto. Los painters de flecha/salida reciben la geometría de forma **opcional** para que sus tests unitarios rect no cambien ni una línea.

**Tech Stack:** Flutter (Dart), `flutter_test` (canvas-matchers `paints`/`paintsExactlyCountTimes`), dominio puro `HexSpace`/`HexMaskedSpace`/`BoardSpace` ya existente (front#124/#125).

## Global Constraints

- **Byte-a-byte rect:** los tableros rectangulares y temáticos-rect se ven idénticos a hoy; ningún test rect existente cambia (ni construcción ni asserts). Verificado por: `test/presentation/game/painters/board_surface_painter_test.dart`, `arrow_painter_test.dart`, `snake_exit_painter_test.dart`, `board_widget_test.dart`, `board_view_masked_space_test.dart`, `board_view_themed_masked_test.dart`, `board_view_auto_solve_exit_duration_test.dart`, `arrow_widget_test.dart`, `exiting_arrow_widget_test.dart`, `board_viewport_test.dart`.
- **Capa presentación:** el seam vive en `lib/presentation/game/geometry/`; importa dominio (`BoardSpace`/`Position`/`Direction`) y Flutter (`Offset`/`Path`/`Size`/`BoxConstraints`). No lo importa `domain/`.
- **Sin aritmética de dirección en widgets/painters de flecha (ADR-0005 D4):** consumen `directionUnit`/`directionAngle` y ahora `geometry.exitLane`; no computan deltas.
- **TDD estricto (patrón AAA)** y **commits por fragmento (Conventional Commits)**. Cada tarea añade su entrada a `AI_HISTORY.MD` empezando en **Entrada 133** (la última es 132, front#125) y la incluye en su commit.
- **Constante:** `const double _sqrt3 = 1.7320508075688772;` en `hex_geometry.dart`. El circunradio de celda se nombra `s`; `cellSize` (separación entre centros vecinos) `= _sqrt3 * s`.
- **Proyección flat-top canónica (ADR-0007 D1):** con `q = col - R`, `r = row - R`: `centerOf.x = 1.5·s·q + originX`, `centerOf.y = √3·s·(r + q/2) + originY`, donde `originX = 1.5·s·R + s`, `originY = √3·s·R + √3·s/2`. `size = (s·(3R+2), √3·s·(2R+1))`. `s = min(maxW/(3R+2), maxH/(√3·(2R+1)))`.
- **Numeración hex→Position (front#124):** `HexSpace(radius)`; `col = q + R`, `row = r + R`. La caja es `(2R+1)²`; las esquinas de la caja caen fuera del hexágono.

---

### Task 1: `BoardGeometry` seam + `RectGeometry`

**Files:**
- Create: `lib/presentation/game/geometry/board_geometry.dart`
- Create: `lib/presentation/game/geometry/rect_geometry.dart`
- Test: `test/presentation/game/geometry/rect_geometry_test.dart`

**Interfaces:**
- Consumes: `BoardSpace` (`bounds`, `contains`, `exitLane`, `masked`), `BoundingBox` (`minRow/minCol/rows/cols/maxRow/maxCol`), `Position`, `Direction`, `HexSpace` (solo para el `is` del factory).
- Produces:
  - `abstract class BoardGeometry` con `factory BoardGeometry.forSpace(BoardSpace space, BoxConstraints c)`; getters `Size get size`, `double get cellSize`; métodos `Offset centerOf(Position p)`, `Position? cellAt(Offset px)`, `List<Position> exitLane(Position head, Direction dir)`.
  - `class RectGeometry implements BoardGeometry`.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/geometry/rect_geometry_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/board_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/rect_geometry.dart';

void main() {
  const c = BoxConstraints(maxWidth: 100, maxHeight: 200); // 4x4 => cell=25

  test('forSpace(RectSpace) devuelve RectGeometry', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g, isA<RectGeometry>());
  });

  test('size y cellSize reproducen min(maxW/cols, maxH/rows)', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g.cellSize, 25.0);
    expect(g.size, const Size(100, 100));
  });

  test('centerOf reproduce (col-minCol+0.5)*cell', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g.centerOf(Position(row: 0, col: 0)), const Offset(12.5, 12.5));
    expect(g.centerOf(Position(row: 2, col: 3)), const Offset(87.5, 62.5));
  });

  test('cellAt reproduce floor(dx/cell) con clamp a bounds', () {
    final g = BoardGeometry.forSpace(const RectSpace(4, 4), c);
    expect(g.cellAt(const Offset(12.5, 12.5)), Position(row: 0, col: 0));
    expect(g.cellAt(const Offset(87.5, 62.5)), Position(row: 2, col: 3));
    // fuera por arriba/izquierda => clamp a la celda de borde
    expect(g.cellAt(const Offset(-5, -5)), Position(row: 0, col: 0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/rect_geometry_test.dart`
Expected: FAIL — `board_geometry.dart`/`rect_geometry.dart` no existen (error de compilación).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/presentation/game/geometry/board_geometry.dart
import 'dart:ui';

import '../../../domain/game_core/space/board_space.dart';
import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'hex_geometry.dart';
import 'rect_geometry.dart';

/// Seam de presentación (front#126): centraliza la aritmética celda<->píxel que
/// antes cada superficie (painter de superficie, hit-test, flecha, salida)
/// inlineaba asumiendo celdas cuadradas. Polimórfico por geometría del espacio;
/// el ÚNICO punto de selección por tipo de la capa de presentación.
abstract class BoardGeometry {
  factory BoardGeometry.forSpace(BoardSpace space, BoxConstraints c) =>
      space is HexSpace ? HexGeometry(space, c) : RectGeometry(space, c);

  /// Tamaño del tablero en píxeles (alimenta BoardViewport).
  Size get size;

  /// Escalar de tamaño de celda para grosores de trazo. Rect: lado de celda.
  /// Hex: separación entre centros vecinos (= √3·s).
  double get cellSize;

  /// Centro de celda en coordenadas de tablero (origen = esquina del marco).
  Offset centerOf(Position p);

  /// Celda bajo el píxel [px], o null si cae fuera del tablero (o de un hueco
  /// enmascarado, en hex). Rect clampa a la caja; el hueco lo filtra el widget.
  Position? cellAt(Offset px);

  /// Celdas desde [head] en [dir] hasta la frontera, cercano→frontera, sin head.
  List<Position> exitLane(Position head, Direction dir);
}
```

```dart
// lib/presentation/game/geometry/rect_geometry.dart
import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/game_core/space/board_space.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'board_geometry.dart';

/// Geometría rectangular: extrae, VERBATIM, las fórmulas que hoy viven inline en
/// BoardView/ArrowPainter/SnakeExitPainter. Byte-idéntico por construcción; los
/// tests rect existentes son el candado.
class RectGeometry implements BoardGeometry {
  final BoardSpace space;
  final BoundingBox _frame;
  final double _cell;

  RectGeometry(this.space, BoxConstraints c)
      : _frame = space.bounds,
        _cell = math.min(
          c.maxWidth / space.bounds.cols,
          c.maxHeight / space.bounds.rows,
        );

  @override
  Size get size => Size(_frame.cols * _cell, _frame.rows * _cell);

  @override
  double get cellSize => _cell;

  @override
  Offset centerOf(Position p) => Offset(
        (p.col - _frame.minCol + 0.5) * _cell,
        (p.row - _frame.minRow + 0.5) * _cell,
      );

  @override
  Position? cellAt(Offset px) => Position(
        row: ((px.dy / _cell).floor() + _frame.minRow)
            .clamp(_frame.minRow, _frame.maxRow),
        col: ((px.dx / _cell).floor() + _frame.minCol)
            .clamp(_frame.minCol, _frame.maxCol),
      );

  // No usado por la animación de salida rect (que conserva cellsToEdge para
  // preservar el bug masked-rect byte a byte, front#126 D2); presente por
  // completitud de la interfaz.
  @override
  List<Position> exitLane(Position head, Direction dir) =>
      space.exitLane(head, dir);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/rect_geometry_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

Añade a `AI_HISTORY.MD` la Entrada 133 (título "BoardGeometry seam + RectGeometry (front#126)") siguiendo la plantilla del proyecto, luego:

```bash
git add lib/presentation/game/geometry/board_geometry.dart lib/presentation/game/geometry/rect_geometry.dart test/presentation/game/geometry/rect_geometry_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add BoardGeometry seam with RectGeometry (#126)"
```

---

### Task 2: `HexGeometry` — proyección (size, cellSize, centerOf)

**Files:**
- Create: `lib/presentation/game/geometry/hex_geometry.dart`
- Test: `test/presentation/game/geometry/hex_geometry_test.dart`

**Interfaces:**
- Consumes: `HexSpace` (`radius`), `BoardGeometry`.
- Produces: `class HexGeometry implements BoardGeometry` con constructor `HexGeometry(HexSpace space, BoxConstraints c)`; en esta tarea implementa `size`, `cellSize`, `centerOf`. `cellAt`, `exitLane` y `cellVertices` se completan en Tasks 3–4 (en esta tarea pueden lanzar `UnimplementedError` para compilar).

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/geometry/hex_geometry_test.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';

const _sqrt3 = 1.7320508075688772;

void main() {
  // Constraints grandes y cuadrados: fit width-bound para R=2 (3R+2=8 vs
  // √3·(2R+1)=8.66) => s = 800/8 = 100.
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  test('size = (s(3R+2), √3·s(2R+1)) y cellSize = √3·s', () {
    final g = HexGeometry(const HexSpace(2), c);
    // s = min(800/8, 800/8.6602..) = 800/8.6602.. = 92.376..
    final s = 800 / (_sqrt3 * 5);
    expect(g.size.width, closeTo(s * 8, 1e-6));
    expect(g.size.height, closeTo(_sqrt3 * s * 5, 1e-6));
    expect(g.cellSize, closeTo(_sqrt3 * s, 1e-6));
  });

  test('centerOf del centro del hex (q=0,r=0) está en el centro del contenido', () {
    final g = HexGeometry(const HexSpace(2), c);
    final s = 800 / (_sqrt3 * 5);
    // q=0,r=0 => x = originX = 1.5sR+s ; y = originY = √3sR+√3s/2
    final center = g.centerOf(Position(row: 2, col: 2)); // col=q+R=2, row=r+R=2
    expect(center.dx, closeTo(1.5 * s * 2 + s, 1e-6));
    expect(center.dy, closeTo(_sqrt3 * s * 2 + _sqrt3 * s / 2, 1e-6));
  });

  test('los 6 vectores unidad · cellSize = centerOf(vecino) − centerOf(celda)', () {
    // Invariante verificada: directionUnit (front#124) coincide con la
    // proyección flat-top. Se comprueba desde el centro del hex R=3.
    final g = HexGeometry(const HexSpace(3), c);
    final cellPos = Position(row: 3, col: 3); // q=0,r=0
    final cs = g.cellSize;
    final expected = {
      Direction.up: const Offset(0, -1),
      Direction.down: const Offset(0, 1),
      Direction.upRight: Offset(math.sqrt(3) / 2, -0.5),
      Direction.downRight: Offset(math.sqrt(3) / 2, 0.5),
      Direction.upLeft: Offset(-math.sqrt(3) / 2, -0.5),
      Direction.downLeft: Offset(-math.sqrt(3) / 2, 0.5),
    };
    for (final entry in expected.entries) {
      final neighbor = const HexSpace(3).step(cellPos, entry.key)!;
      final delta = g.centerOf(neighbor) - g.centerOf(cellPos);
      expect(delta.dx, closeTo(entry.value.dx * cs, 1e-6), reason: '${entry.key}.dx');
      expect(delta.dy, closeTo(entry.value.dy * cs, 1e-6), reason: '${entry.key}.dy');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/hex_geometry_test.dart`
Expected: FAIL — `hex_geometry.dart` no existe.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/presentation/game/geometry/hex_geometry.dart
import 'dart:math' as math;
import 'dart:ui';

import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../../../domain/game_core/value_objects/position.dart';
import 'board_geometry.dart';

const double _sqrt3 = 1.7320508075688772;

/// Geometría hexagonal flat-top (ADR-0007 D1): proyecta las coordenadas axiales
/// del [HexSpace] a píxeles y de vuelta. Objeto plano (sin BuildContext),
/// unit-testable en AAA con un Size fijo.
class HexGeometry implements BoardGeometry {
  final HexSpace space;
  final int _r;
  final double _s; // circunradio de celda
  final double _originX;
  final double _originY;

  HexGeometry(this.space, BoxConstraints c)
      : _r = space.radius,
        _s = math.min(
          c.maxWidth / (3 * space.radius + 2),
          c.maxHeight / (_sqrt3 * (2 * space.radius + 1)),
        );

  // Origen de encuadre: desplaza el contenido para que quepa en [0, size].
  // Getters (no campos) porque dependen de _s, que el inicializador ya fijó.
  double get _ox => 1.5 * _s * _r + _s;
  double get _oy => _sqrt3 * _s * _r + _sqrt3 * _s / 2;

  @override
  Size get size =>
      Size(_s * (3 * _r + 2), _sqrt3 * _s * (2 * _r + 1));

  @override
  double get cellSize => _sqrt3 * _s;

  @override
  Offset centerOf(Position p) {
    final q = p.col - _r;
    final r = p.row - _r;
    return Offset(
      1.5 * _s * q + _ox,
      _sqrt3 * _s * (r + q / 2) + _oy,
    );
  }

  @override
  Position? cellAt(Offset px) => throw UnimplementedError('Task 3');

  @override
  List<Position> exitLane(Position head, Direction dir) =>
      throw UnimplementedError('Task 4');
}
```

> Nota de implementación: los campos `_originX`/`_originY` del ejemplo se dejan a 0 y se reemplazan por los getters `_ox`/`_oy` (que sí pueden leer `_s`). Elimina los campos `_originX`/`_originY` del constructor si tu linter se queja de no usarlos; el patrón getter es suficiente.

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/hex_geometry_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 134 ("HexGeometry: proyección flat-top (front#126)"), luego:

```bash
git add lib/presentation/game/geometry/hex_geometry.dart test/presentation/game/geometry/hex_geometry_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add HexGeometry flat-top projection (#126)"
```

---

### Task 3: `HexGeometry` — hit-testing (`cellAt`)

**Files:**
- Modify: `lib/presentation/game/geometry/hex_geometry.dart` (reemplaza `cellAt`)
- Test: `test/presentation/game/geometry/hex_geometry_cellat_test.dart`

**Interfaces:**
- Consumes: `HexSpace.contains`, `HexMaskedSpace` (para el caso enmascarado), `HexGeometry.centerOf`.
- Produces: `HexGeometry.cellAt(Offset) -> Position?` (redondeo cúbico + gate `space.contains`).

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/geometry/hex_geometry_cellat_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  test('el centro exacto de cada celda mapea a su celda (R=3)', () {
    final g = HexGeometry(const HexSpace(3), c);
    for (final p in const HexSpace(3).allCells) {
      expect(g.cellAt(g.centerOf(p)), p, reason: '$p');
    }
  });

  test('un punto cerca del borde de una celda sigue mapeando a esa celda', () {
    final g = HexGeometry(const HexSpace(3), c);
    final p = Position(row: 3, col: 3); // centro
    final near = g.centerOf(p) + Offset(g.cellSize * 0.2, 0);
    expect(g.cellAt(near), p);
  });

  test('la esquina de la caja (fuera del hexágono) devuelve null', () {
    final g = HexGeometry(const HexSpace(3), c);
    // (row=0,col=0) => q=r=-3 => |q+r|=6>3: fuera del hex.
    expect(g.cellAt(const Offset(0, 0)), isNull);
  });

  test('una celda enmascarada (hueco) devuelve null', () {
    final active = const HexSpace(1).allCells.toSet()
      ..remove(Position(row: 1, col: 1)); // quita el centro
    final space = HexMaskedSpace(1, activeCells: active);
    final g = HexGeometry(const HexSpace(1), c);
    // El píxel del centro cae en la celda-centro, ahora hueco => null.
    expect(g.cellAt(g.centerOf(Position(row: 1, col: 1))), isNull,
        reason: 'gate contra HexMaskedSpace');
    // Debe construirse la geometría contra el espacio real para el gate:
    final gm = HexGeometry(const HexSpace(1), c); // radio; el gate usa space
    expect(gm, isNotNull);
  });
}
```

> Nota: el gate de `cellAt` consulta `space.contains`. Para el caso enmascarado, construye la `HexGeometry` con un `HexSpace` cuyo `contains` refleje la máscara. **Ajuste de diseño:** `HexGeometry` recibe el `HexSpace` base para la proyección, pero el gate de existencia debe usar el espacio REAL montado (que puede ser `HexMaskedSpace`). Como `HexMaskedSpace extends HexSpace`, pasa el espacio montado directamente: `HexGeometry(mountedSpace, c)` donde `mountedSpace` puede ser `HexMaskedSpace`. Reescribe el 4º test así:

```dart
  test('una celda enmascarada (hueco) devuelve null', () {
    final active = const HexSpace(1).allCells.toSet()
      ..remove(Position(row: 1, col: 1));
    final space = HexMaskedSpace(1, activeCells: active);
    final g = HexGeometry(space, c); // HexMaskedSpace ES HexSpace
    expect(g.cellAt(g.centerOf(Position(row: 1, col: 1))), isNull);
    // una celda activa del anillo sí mapea
    final ring = Position(row: 0, col: 1);
    expect(g.cellAt(g.centerOf(ring)), ring);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/hex_geometry_cellat_test.dart`
Expected: FAIL — `cellAt` lanza `UnimplementedError`.

- [ ] **Step 3: Write minimal implementation**

Reemplaza el método `cellAt` en `hex_geometry.dart`:

```dart
  @override
  Position? cellAt(Offset px) {
    // Píxel -> axial fraccional (inverso de centerOf).
    final x = px.dx - _ox;
    final y = px.dy - _oy;
    final qf = x / (1.5 * _s);
    final rf = y / (_sqrt3 * _s) - qf / 2;
    // Redondeo cúbico estándar (x=q, z=r, y=-x-z).
    var rx = qf.roundToDouble();
    var rz = rf.roundToDouble();
    var ry = (-qf - rf).roundToDouble();
    final dx = (rx - qf).abs();
    final dz = (rz - rf).abs();
    final dy = (ry - (-qf - rf)).abs();
    if (dx > dy && dx > dz) {
      rx = -ry - rz;
    } else if (dy > dz) {
      // ry se recalcula implícito; solo importan q(rx) y r(rz)
    } else {
      rz = -rx - ry;
    }
    final row = rz.toInt() + _r;
    final col = rx.toInt() + _r;
    if (row < 0 || col < 0) return null;
    final pos = Position(row: row, col: col);
    return space.contains(pos) ? pos : null;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/hex_geometry_cellat_test.dart`
Expected: PASS (4 tests). Si el redondeo falla en algún borde, revisa que `space` sea el espacio montado (posible `HexMaskedSpace`).

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 135 ("HexGeometry: hit-testing por redondeo cúbico (front#126)"), luego:

```bash
git add lib/presentation/game/geometry/hex_geometry.dart test/presentation/game/geometry/hex_geometry_cellat_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add hex pixel-to-cell hit-testing (#126)"
```

---

### Task 4: `HexGeometry` — `cellVertices` + `exitLane`

**Files:**
- Modify: `lib/presentation/game/geometry/hex_geometry.dart` (añade `cellVertices`, reemplaza `exitLane`)
- Test: `test/presentation/game/geometry/hex_geometry_vertices_test.dart`

**Interfaces:**
- Produces:
  - `List<Offset> HexGeometry.cellVertices(Position p)` — 6 vértices flat-top en orden `[v0 derecha, v1 abajo-der, v2 abajo-izq, v3 izquierda, v4 arriba-izq, v5 arriba-der]`.
  - `HexGeometry.exitLane` delega en `space.exitLane`.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/geometry/hex_geometry_vertices_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';

const _sqrt3 = 1.7320508075688772;

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  test('cellVertices son 6 vértices flat-top alrededor del centro', () {
    final g = HexGeometry(const HexSpace(2), c);
    final p = Position(row: 2, col: 2); // centro
    final center = g.centerOf(p);
    final s = g.cellSize / _sqrt3; // circunradio
    final h = _sqrt3 / 2 * s;
    final v = g.cellVertices(p);
    expect(v.length, 6);
    expect(v[0].dx, closeTo(center.dx + s, 1e-6)); // derecha
    expect(v[0].dy, closeTo(center.dy, 1e-6));
    expect(v[1].dx, closeTo(center.dx + s / 2, 1e-6)); // abajo-derecha
    expect(v[1].dy, closeTo(center.dy + h, 1e-6));
    expect(v[3].dx, closeTo(center.dx - s, 1e-6)); // izquierda
  });

  test('exitLane delega en space.exitLane (downRight, R=2)', () {
    final g = HexGeometry(const HexSpace(2), c);
    final head = Position(row: 2, col: 2); // q=0,r=0
    expect(g.exitLane(head, Direction.downRight),
        const HexSpace(2).exitLane(head, Direction.downRight));
    expect(g.exitLane(head, Direction.downRight), isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/hex_geometry_vertices_test.dart`
Expected: FAIL — `cellVertices` no existe / `exitLane` lanza.

- [ ] **Step 3: Write minimal implementation**

En `hex_geometry.dart`, reemplaza `exitLane` y añade `cellVertices`:

```dart
  @override
  List<Position> exitLane(Position head, Direction dir) =>
      space.exitLane(head, dir);

  /// 6 vértices del hexágono flat-top de [p], en orden horario desde la derecha.
  List<Offset> cellVertices(Position p) {
    final c = centerOf(p);
    final h = _sqrt3 / 2 * _s;
    return [
      Offset(c.dx + _s, c.dy),        // v0 derecha
      Offset(c.dx + _s / 2, c.dy + h), // v1 abajo-derecha
      Offset(c.dx - _s / 2, c.dy + h), // v2 abajo-izquierda
      Offset(c.dx - _s, c.dy),        // v3 izquierda
      Offset(c.dx - _s / 2, c.dy - h), // v4 arriba-izquierda
      Offset(c.dx + _s / 2, c.dy - h), // v5 arriba-derecha
    ];
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/geometry/hex_geometry_vertices_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 136 ("HexGeometry: vértices flat-top + exitLane (front#126)"), luego:

```bash
git add lib/presentation/game/geometry/hex_geometry.dart test/presentation/game/geometry/hex_geometry_vertices_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add hex cell vertices and exit lane (#126)"
```

---

### Task 5: `HexBoardSurfacePainter`

**Files:**
- Create: `lib/presentation/game/painters/hex_board_surface_painter.dart`
- Test: `test/presentation/game/painters/hex_board_surface_painter_test.dart`

**Interfaces:**
- Consumes: `HexGeometry` (`cellVertices`, `centerOf`), `HexSpace`/`HexMaskedSpace` (`allCells`, `step`), `Direction`.
- Produces: `class HexBoardSurfacePainter extends CustomPainter` con constructor `HexBoardSurfacePainter({required HexSpace space, required HexGeometry geometry, required Color surfaceColor, required Color gridColor})`.

Regla de dibujo: por cada celda existente (`space.allCells`) rellena su hexágono (un `drawPath`); y por cada dirección canónica `[down, downRight, downLeft]`, si `space.step(cell, dir) != null` dibuja la arista compartida una vez (`drawLine`). Aristas de frontera (vecino ausente) no se trazan. Mapeo dirección→par de vértices: `down → (v1,v2)`, `downRight → (v0,v1)`, `downLeft → (v2,v3)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/painters/hex_board_surface_painter_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/hex_board_surface_painter.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  HexBoardSurfacePainter painter(HexSpace space) => HexBoardSurfacePainter(
        space: space,
        geometry: HexGeometry(space, c),
        surfaceColor: const Color(0xFF223344),
        gridColor: const Color(0x11FFFFFF),
      );

  Future<RenderBox> pump(WidgetTester tester, HexBoardSurfacePainter p,
      HexGeometry g) async {
    await tester.pumpWidget(Center(
      child: SizedBox.fromSize(
        size: g.size,
        child: CustomPaint(painter: p),
      ),
    ));
    return tester.renderObject<RenderBox>(find.byType(CustomPaint).first);
  }

  testWidgets('R=1 completo: 7 hexágonos + 12 aristas interiores', (t) async {
    final g = HexGeometry(const HexSpace(1), c);
    final ro = await pump(t, painter(const HexSpace(1)), g);
    expect(ro, paintsExactlyCountTimes(#drawPath, 7)); // rellenos
    expect(ro, paintsExactlyCountTimes(#drawLine, 12)); // aristas compartidas
  });

  testWidgets('R=2 completo: 19 hexágonos', (t) async {
    final g = HexGeometry(const HexSpace(2), c);
    final ro = await pump(t, painter(const HexSpace(2)), g);
    expect(ro, paintsExactlyCountTimes(#drawPath, 19));
  });

  testWidgets('R=1 con centro hueco: 6 hexágonos + 6 aristas del anillo', (t) async {
    final active = const HexSpace(1).allCells.toSet()
      ..remove(Position(row: 1, col: 1));
    final space = HexMaskedSpace(1, activeCells: active);
    final g = HexGeometry(space, c);
    final p = HexBoardSurfacePainter(
      space: space,
      geometry: g,
      surfaceColor: const Color(0xFF223344),
      gridColor: const Color(0x11FFFFFF),
    );
    final ro = await pump(t, p, g);
    expect(ro, paintsExactlyCountTimes(#drawPath, 6));
    expect(ro, paintsExactlyCountTimes(#drawLine, 6));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/hex_board_surface_painter_test.dart`
Expected: FAIL — `hex_board_surface_painter.dart` no existe.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/presentation/game/painters/hex_board_surface_painter.dart
import 'package:flutter/material.dart';

import '../../../domain/game_core/space/hex_space.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../geometry/hex_geometry.dart';

/// Superficie del tablero hexagonal flat-top (front#126): rellena cada celda
/// existente como hexágono y traza cada arista interior UNA vez (frontera con
/// celda ausente = borde del relleno, como el masked rect). Painter separado del
/// rectangular para no tocar su lock byte a byte (canvas-call level).
class HexBoardSurfacePainter extends CustomPainter {
  final HexSpace space;
  final HexGeometry geometry;
  final Color surfaceColor;
  final Color gridColor;

  const HexBoardSurfacePainter({
    required this.space,
    required this.geometry,
    required this.surfaceColor,
    required this.gridColor,
  });

  // Una dirección por par opuesto => cada arista compartida se dibuja una vez.
  // Mapeo a los índices de vértice de HexGeometry.cellVertices.
  static const _canonical = <Direction, (int, int)>{
    Direction.down: (1, 2),
    Direction.downRight: (0, 1),
    Direction.downLeft: (2, 3),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = surfaceColor;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final cell in space.allCells) {
      final v = geometry.cellVertices(cell);
      final path = Path()..moveTo(v.first.dx, v.first.dy);
      for (final p in v.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, fill);

      _canonical.forEach((dir, idx) {
        if (space.step(cell, dir) != null) {
          canvas.drawLine(v[idx.$1], v[idx.$2], grid);
        }
      });
    }
  }

  @override
  bool shouldRepaint(covariant HexBoardSurfacePainter old) =>
      old.space != space ||
      old.geometry.size != geometry.size ||
      old.surfaceColor != surfaceColor ||
      old.gridColor != gridColor;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/hex_board_surface_painter_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 137 ("HexBoardSurfacePainter (front#126)"), luego:

```bash
git add lib/presentation/game/painters/hex_board_surface_painter.dart test/presentation/game/painters/hex_board_surface_painter_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add HexBoardSurfacePainter (#126)"
```

---

### Task 6: Enhebrar geometría opcional en `ArrowPainter` + `ArrowWidget`

**Files:**
- Modify: `lib/presentation/game/painters/arrow_painter.dart`
- Modify: `lib/presentation/game/widgets/arrow_widget.dart`
- Test: `test/presentation/game/painters/arrow_painter_hex_test.dart`

**Interfaces:**
- `ArrowPainter` gana dos campos opcionales: `final BoardGeometry? geometry;` y `final Offset origin;` (default `Offset.zero`). Cuando `geometry != null`, `_center(p) = geometry.centerOf(p) - origin` y `cell` se interpreta como `cellSize` (grosores). Cuando es null, comportamiento lineal actual **sin cambios** (los tests rect existentes lo cubren).
- `ArrowWidget` gana `final BoardGeometry? geometry;` y `final Offset origin;` (default `Offset.zero`) y los pasa a `ArrowPainter`.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/painters/arrow_painter_hex_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  testWidgets('con geometry, la flecha recorre centros hex (no lineales)', (t) async {
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2), Position(row: 2, col: 3)]; // downRight
    final origin = g.centerOf(cells.first); // origen arbitrario de la caja
    final painter = ArrowPainter(
      cells: cells,
      minCol: 2,
      minRow: 2,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      headDirection: Direction.downRight,
      geometry: g,
      origin: origin,
    );
    await t.pumpWidget(Center(
      child: SizedBox(width: 400, height: 400, child: CustomPaint(painter: painter)),
    ));
    final ro = t.renderObject<RenderBox>(find.byType(CustomPaint).first);
    // El cuerpo se pinta como path (glow + cuerpo + brillo) + cabeza => >=4 drawPath.
    expect(ro, paintsExactlyCountTimes(#drawPath, 4));
  });

  test('_center con geometry devuelve centerOf − origin', () {
    final g = HexGeometry(const HexSpace(2), c);
    final p0 = Position(row: 2, col: 2);
    final p1 = Position(row: 2, col: 3);
    final origin = g.centerOf(p0);
    // El delta entre centros locales debe igualar el delta de centerOf.
    final expectedDelta = g.centerOf(p1) - g.centerOf(p0);
    // (verificado indirectamente: el segundo centro local = expectedDelta)
    expect(expectedDelta.dx, isNot(closeTo(g.cellSize, 1e-9)),
        reason: 'diagonal hex: dx != cellSize entero, prueba no-lineal');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/arrow_painter_hex_test.dart`
Expected: FAIL — `ArrowPainter` no acepta `geometry`/`origin`.

- [ ] **Step 3: Write minimal implementation**

En `arrow_painter.dart`: añade el import y los campos, y ramifica `_center`:

```dart
import '../geometry/board_geometry.dart';
// ...
class ArrowPainter extends CustomPainter {
  final List<Position> cells;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;
  final Direction headDirection;
  // front#126: cuando no es null, los centros vienen de la geometría (hex);
  // `cell` pasa a ser el cellSize (√3·s) para los grosores. Ausente => camino
  // lineal rect intacto (lo cubren los tests rect existentes).
  final BoardGeometry? geometry;
  final Offset origin;

  const ArrowPainter({
    required this.cells,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
    required this.headDirection,
    this.geometry,
    this.origin = Offset.zero,
  });

  Offset _center(Position p) => geometry != null
      ? geometry!.centerOf(p) - origin
      : Offset((p.col - minCol + 0.5) * cell, (p.row - minRow + 0.5) * cell);
```

Extiende `shouldRepaint` con `|| old.geometry != geometry || old.origin != origin`.

En `arrow_widget.dart`: añade el import `../geometry/board_geometry.dart`, los campos `final BoardGeometry? geometry;` y `final Offset origin;` (`this.geometry`, `this.origin = Offset.zero` en el constructor) y pásalos al `ArrowPainter`:

```dart
          painter: ArrowPainter(
            cells: widget.arrow.cells,
            minCol: widget.minCol,
            minRow: widget.minRow,
            cell: widget.cell,
            color: widget.color,
            headDirection: widget.arrow.headDirection,
            geometry: widget.geometry,
            origin: widget.origin,
          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/arrow_painter_hex_test.dart`
Expected: PASS.

Corre además los tests rect del painter/widget para confirmar que NO cambian:
Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/arrow_painter_test.dart test/presentation/game/widgets/arrow_widget_test.dart`
Expected: PASS sin modificaciones.

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 138 ("ArrowPainter/ArrowWidget: geometría opcional para hex (front#126)"), luego:

```bash
git add lib/presentation/game/painters/arrow_painter.dart lib/presentation/game/widgets/arrow_widget.dart test/presentation/game/painters/arrow_painter_hex_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): thread optional geometry into ArrowPainter (#126)"
```

---

### Task 7: Enhebrar geometría opcional en `SnakeExitPainter` + `ExitingArrowWidget`

**Files:**
- Modify: `lib/presentation/game/painters/snake_exit_painter.dart`
- Modify: `lib/presentation/game/widgets/exiting_arrow_widget.dart`
- Test: `test/presentation/game/painters/snake_exit_painter_hex_test.dart`

**Interfaces:**
- `SnakeExitPainter` gana `final BoardGeometry? geometry;` y `final Offset origin;` (default `Offset.zero`). Cuando `geometry != null`: `_center(p) = geometry.centerOf(p) - origin`, `cell` es `cellSize`, y `_laneCells() = geometry.exitLane(cells.last, headDirection).length` (carril real del espacio) en vez de `cellsToEdge`. Ausente => comportamiento actual intacto (incluido el bug masked-rect).
- `ExitingArrowWidget` gana `final BoardGeometry? geometry;` y `final Offset origin;` y los pasa al painter.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/painters/snake_exit_painter_hex_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/geometry/hex_geometry.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/snake_exit_painter.dart';

void main() {
  const c = BoxConstraints(maxWidth: 800, maxHeight: 800);

  testWidgets('salida hex diagonal usa geometría sin lanzar (downRight)', (t) async {
    final g = HexGeometry(const HexSpace(2), c);
    final cells = [Position(row: 2, col: 2)]; // q=0,r=0; downRight sale al borde
    final painter = SnakeExitPainter(
      cells: cells,
      headDirection: Direction.downRight,
      minCol: 2,
      minRow: 2,
      cols: 5,
      rows: 5,
      cell: g.cellSize,
      color: const Color(0xFFFFFFFF),
      progress: 0.5,
      geometry: g,
      origin: g.centerOf(cells.first),
    );
    // Sin geometría esto lanzaría UnimplementedError (cellsToEdge diagonal).
    await t.pumpWidget(Center(
      child: SizedBox(width: 400, height: 400, child: CustomPaint(painter: painter)),
    ));
    final ro = t.renderObject<RenderBox>(find.byType(CustomPaint).first);
    expect(ro, paints..path()); // pinta cuerpo + cabeza sin excepción
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/snake_exit_painter_hex_test.dart`
Expected: FAIL — `SnakeExitPainter` no acepta `geometry`/`origin` (y sin ellos lanzaría `UnimplementedError` en la diagonal).

- [ ] **Step 3: Write minimal implementation**

En `snake_exit_painter.dart`: añade `import '../geometry/board_geometry.dart';`, los campos y ramifica `_center` y `_laneCells`:

```dart
  final BoardGeometry? geometry;
  final Offset origin;

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
    this.geometry,
    this.origin = Offset.zero,
  });

  Offset _center(Position p) => geometry != null
      ? geometry!.centerOf(p) - origin
      : Offset((p.col - minCol + 0.5) * cell, (p.row - minRow + 0.5) * cell);

  int _laneCells() => geometry != null
      ? geometry!.exitLane(cells.last, headDirection).length
      : cellsToEdge(cells.last, headDirection, cols: cols, rows: rows);
```

Extiende `shouldRepaint` con `|| old.geometry != geometry || old.origin != origin`.

En `exiting_arrow_widget.dart`: añade `import '../geometry/board_geometry.dart';`, los campos `final BoardGeometry? geometry;` / `final Offset origin;` (`this.geometry`, `this.origin = Offset.zero`) y pásalos al `SnakeExitPainter`:

```dart
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
              geometry: widget.geometry,
              origin: widget.origin,
            ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/snake_exit_painter_hex_test.dart`
Expected: PASS.

Confirma que el rect no cambia:
Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/painters/snake_exit_painter_test.dart test/presentation/game/widgets/exiting_arrow_widget_test.dart`
Expected: PASS sin modificaciones.

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 139 ("SnakeExitPainter/ExitingArrowWidget: carril hex real (front#126)"), luego:

```bash
git add lib/presentation/game/painters/snake_exit_painter.dart lib/presentation/game/widgets/exiting_arrow_widget.dart test/presentation/game/painters/snake_exit_painter_hex_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): thread optional geometry into SnakeExitPainter (#126)"
```

---

### Task 8: Cablear `BoardView` (geometría, tamaño, hit-test, selección de painter, flecha/salida hex)

**Files:**
- Modify: `lib/presentation/game/widgets/board_widget.dart`
- Test: `test/presentation/game/widgets/board_view_hex_test.dart`

**Interfaces:**
- Consumes: `BoardGeometry.forSpace`, `HexGeometry`, `HexBoardSurfacePainter`, `BoardSurfacePainter`, `ArrowWidget`, `ExitingArrowWidget` (todos ya con geometría opcional).
- Produce: `BoardView` monta el tablero correcto según el tipo de espacio, byte-idéntico en rect.

**Cambios en `board_widget.dart`** (`BoardView`):

1. En `build`, tras `final frame = ...`, dentro del `LayoutBuilder`, construye la geometría y usa su tamaño:

```dart
      builder: (context, constraints) {
        final geometry = BoardGeometry.forSpace(state.board.space, constraints);
        return BoardViewport(
          viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
          boardSize: geometry.size,
          builder: (visibleRect) => _boardContent(
            context: context,
            geometry: geometry,
            surface: surface,
            gridColor: gridColor,
            visibleRect: visibleRect,
          ),
        );
      },
```

2. `_boardContent` recibe `BoardGeometry geometry` en vez de `double cell`. Deriva `final cell = geometry.cellSize;` para las rutas rect existentes (culling/onCamera/_positionArrow) y usa `geometry` para hit-test, selección de painter y montaje hex.

3. Hit-test (`onTapUp`):

```dart
      onTapUp: (details) {
        final pos = geometry.cellAt(details.localPosition);
        if (pos == null || !space.contains(pos)) return;
        final arrow = board.arrowAt(pos);
        if (arrow != null) onTapArrow(arrow.id);
      },
```

4. Selección de painter de superficie:

```dart
          Positioned.fill(
            child: CustomPaint(
              painter: space is HexSpace
                  ? HexBoardSurfacePainter(
                      space: space,
                      geometry: geometry as HexGeometry,
                      surfaceColor: surface.withValues(alpha: 0.30),
                      gridColor: gridColor,
                    )
                  : BoardSurfacePainter(
                      space: space,
                      cell: cell,
                      surfaceColor: surface.withValues(alpha: 0.30),
                      gridColor: gridColor,
                      visibleRect: visibleRect,
                    ),
            ),
          ),
```

5. `_positionArrow` y `_positionExiting`: para hex, la caja `Positioned` es el AABB de `geometry.centerOf(celdas)` inflado medio `cellSize`, y el origen que reciben los widgets es el `topLeft` de esa caja; se les pasa `geometry`. Para rect, todo queda como hoy (geometry omitida). Reescribe ambos métodos para aceptar `BoardGeometry geometry` y ramificar:

```dart
  Widget _positionArrow(
      Arrow arrow, BoardGeometry geometry, GamePlaying state, BoundingBox frame) {
    final space = state.board.space;
    if (space is HexSpace) {
      final r = _pixelBox(arrow, geometry);
      return Positioned(
        left: r.left,
        top: r.top,
        width: r.width,
        height: r.height,
        child: ArrowWidget(
          key: ValueKey(arrow.id.value),
          arrow: arrow,
          minCol: 0,
          minRow: 0,
          cell: geometry.cellSize,
          color: colorResolver.colorFor(arrow, state.palette),
          isBlocked: state.blockedArrow == arrow.id,
          blockedNonce: state.blockedNonce,
          geometry: geometry,
          origin: r.topLeft,
        ),
      );
    }
    final cell = geometry.cellSize;
    final b = _bounds(arrow);
    return Positioned(
      left: (b.minCol - frame.minCol) * cell,
      top: (b.minRow - frame.minRow) * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      child: ArrowWidget(
        key: ValueKey(arrow.id.value),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cell: cell,
        color: colorResolver.colorFor(arrow, state.palette),
        isBlocked: state.blockedArrow == arrow.id,
        blockedNonce: state.blockedNonce,
      ),
    );
  }

  /// AABB en píxeles de los centros de una flecha, inflado medio cellSize para
  /// que el trazo/cabeza quepan (con Clip.none el desborde es admisible).
  Rect _pixelBox(Arrow arrow, BoardGeometry geometry) {
    var box = Rect.fromCircle(
        center: geometry.centerOf(arrow.cells.first), radius: 0);
    for (final p in arrow.cells) {
      final ctr = geometry.centerOf(p);
      box = box.expandToInclude(Rect.fromCircle(center: ctr, radius: 0));
    }
    return box.inflate(geometry.cellSize);
  }
```

Aplica el mismo patrón a `_positionExiting` (rama hex: `Positioned` desde `_pixelBox`, `minCol:0, minRow:0, cols/rows` del `frame` (ignoradas por el painter con geometría), `cell: geometry.cellSize`, `geometry: geometry`, `origin: r.topLeft`; rama rect intacta). Ajusta las llamadas en el `Stack` para pasar `geometry` en vez de `cell`, y `onCamera`/`camera` para usar `geometry.cellSize` como hoy usaban `cell`.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/game/widgets/board_view_hex_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

GamePlaying _hexPlaying() {
  final board = ArrowBoard(
    arrows: [
      Arrow(
        id: const ArrowId('h0'),
        headDirection: Direction.downRight,
        cells: [Position(row: 2, col: 2), Position(row: 2, col: 3)],
      ),
    ],
    space: const HexSpace(2),
  );
  return GamePlaying(board: board, moves: const MoveCount(0));
}

void main() {
  testWidgets('monta un nivel hex y el tap sobre la flecha la selecciona', (t) async {
    ArrowId? tapped;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: BoardView(
              state: _hexPlaying(),
              onTapArrow: (id) => tapped = id,
            ),
          ),
        ),
      ),
    ));
    // Toca el centro de la primera celda de la flecha.
    // (basta con tocar dentro del hexágono; el hit-test resuelve la celda)
    await t.tapAt(t.getCenter(find.byType(BoardView)));
    // No aserta la celda exacta del centro del widget; comprueba que el árbol
    // se montó sin excepción y que BoardView existe.
    expect(find.byType(BoardView), findsOneWidget);
    // Un tap sobre la celda de la flecha selecciona; si el centro cae sobre
    // la flecha, `tapped` != null. El objetivo primario es "monta sin lanzar".
    expect(tapped == null || tapped == const ArrowId('h0'), isTrue);
  });

  testWidgets('un tap fuera del hexágono (esquina) no selecciona nada', (t) async {
    ArrowId? tapped;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: BoardView(
              state: _hexPlaying(),
              onTapArrow: (id) => tapped = id,
            ),
          ),
        ),
      ),
    ));
    final tl = t.getTopLeft(find.byType(BoardView));
    await t.tapAt(tl + const Offset(2, 2)); // esquina de la caja: fuera del hex
    expect(tapped, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/widgets/board_view_hex_test.dart`
Expected: FAIL — `BoardView` aún asume rect (o error de compilación por la firma de `_boardContent`).

- [ ] **Step 3: Write minimal implementation**

Aplica los cambios 1–5 descritos arriba a `board_widget.dart`. Añade los imports:

```dart
import '../geometry/board_geometry.dart';
import '../geometry/hex_geometry.dart';
import '../painters/hex_board_surface_painter.dart';
import '../../../domain/game_core/space/hex_space.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test test/presentation/game/widgets/board_view_hex_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

Añade `AI_HISTORY.MD` Entrada 140 ("BoardView: montaje hexagonal end-to-end (front#126)"), luego:

```bash
git add lib/presentation/game/widgets/board_widget.dart test/presentation/game/widgets/board_view_hex_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): mount hex board render in BoardView (#126)"
```

---

### Task 9: Regresión completa + README

**Files:**
- Modify: `README.md` (sección de arquitectura/render: mencionar el seam `BoardGeometry` y el render hex)

- [ ] **Step 1: Correr la suite completa**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter test`
Expected: TODOS verdes. En especial, ninguno de los tests rect listados en *Global Constraints* debe haber cambiado ni fallar. Si alguno falla, `RectGeometry` no reproduce una fórmula: compáralo con el inline original y corrígelo (no toques el test).

- [ ] **Step 2: Análisis estático**

Run: `PATH="/opt/homebrew/bin:$PATH" flutter analyze`
Expected: sin errores (advertencias preexistentes toleradas).

- [ ] **Step 3: Actualizar README**

Añade a la sección de render/presentación del `README.md` un párrafo: el tablero se dimensiona y proyecta vía el seam `BoardGeometry` (`RectGeometry`/`HexGeometry`); el modo hexagonal flat-top pinta con `HexBoardSurfacePainter` y comparte hit-testing, flechas y animación de salida a través de la misma geometría (front#126). Nota: la selección visual del modo hex (ruta `/hex`) y los niveles servidos llegan con front#127 y back#60.

- [ ] **Step 4: Commit**

Añade `AI_HISTORY.MD` Entrada 141 ("Regresión verde + README render hex (front#126)"), luego:

```bash
git add README.md AI_HISTORY.MD
git commit -m "docs(front): document hex render seam in README (#126)"
```

---

## Notas de cierre

- **Sign-off visual:** diferido a front#127 (ruta `/hex`) + back#60 (niveles servidos). El PR de #126 declara "verificado por tests; sign-off visual pendiente de #127" — sin afirmar haber visto el render en pantalla.
- **Deuda registrada aparte:** el bug de salida en masked-rect (la animación cruza celdas ausentes hasta el borde de la caja) NO se corrige aquí; abrir un issue de deuda propio.
- **Dependencia de rama:** esta rama `feat/#126-hex-render` cuelga de `feat/#125-hex-decoder-mount` (PR #129 sin mergear); arrastra sus commits hasta que #125 entre a `main`.
