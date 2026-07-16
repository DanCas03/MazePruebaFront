# front#87 — Render y hit-test del tablero vía BoardSpace: Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `BoardView` dimensiona, pinta y hace hit-testing a través de `BoardSpace` (bounds + `contains`), dejando de asumir un rectángulo `cols×rows` — desbloquea siluetas (front#86/#88) sin cambiar un píxel de la campaña rectangular.

**Architecture:** Un nuevo `BoardSurfacePainter` (presentation/painters) reemplaza al par `DecoratedBox` + `_GridPainter` privado de `board_widget.dart`. Tiene dos caminos: caja llena (cada celda del bounding box existe → reproduce el panel redondeado + rejilla actuales, píxel-idéntico) y enmascarado (solo celdas existentes, rejilla solo entre vecinas existentes). `BoardView` pasa a trabajar en coordenadas del MARCO (origen = esquina del `space.bounds`), rechaza toques sobre celdas que no existen vía `space.contains`, y conserva intactos el viewport/culling de front#66. `GeneratedBoardWidget` es un wrapper fino sobre `BoardView`, así que queda cubierto sin tocarlo.

**Tech Stack:** Flutter, flutter_test (matcher `paints`/`paintsExactlyCountTimes` de canvas), Equatable.

## Global Constraints

- **Solo presentación**: cero cambios en `lib/domain/`, `lib/application/`, `lib/infrastructure/` y en el wire. `BoardSpace.bounds`/`BoundingBox` ya existen (#85, mergeado).
- **Regresión dura**: los tests existentes (647) quedan verdes SIN editarlos. Un nivel `RectSpace` renderiza píxel-idéntico: el camino de caja llena porta el código actual literalmente.
- **`contains`, nunca `allCells`, para decidir existencia de celda**: el doble de certificación `HoledRectSpace` (test/support) deliberadamente NO resta agujeros de `allCells`/`cellCount` — discriminar por conteo tomaría el camino de pintado equivocado.
- **Coordenadas del marco**: pixel = (celda absoluta − `bounds.min…`) × cell. Con los espacios de Fase 1 (origen 0) es la identidad; deja listo el recorte al bounding box de front#88 sin reescribir celdas de flechas.
- `flutter analyze` limpio; comandos desde la raíz de `MazePruebaFront/` (o su worktree).
- AI_HISTORY: próxima entrada **086**. Un fragmento significativo = un commit (Conventional Commits). `main` protegida → todo entra por PR; **el usuario decide el merge**.
- Limitación documentada (NO resolver aquí): `ExitingArrowWidget`/`SnakeExitPainter` calculan el recorrido de salida contra un marco `cols×rows` anclado en origen (`cellsToEdge`); en un espacio enmascarado la animación cruza las celdas ausentes hasta el borde de la caja. Cosmético; se revisa con front#88 si molesta.

## File Structure

- Create: `lib/presentation/game/painters/board_surface_painter.dart` — painter del panel+rejilla consciente del espacio (única responsabilidad: pintar la superficie).
- Create: `test/presentation/game/painters/board_surface_painter_test.dart` — geometría del painter (caja llena, enmascarado, culling, shouldRepaint).
- Modify: `lib/presentation/game/widgets/board_widget.dart` — `BoardView` usa el painter, hit-test vía `contains`, traslación al marco; muere `_GridPainter`.
- Create: `test/presentation/game/widgets/board_view_masked_space_test.dart` — tests de widget con espacio enmascarado (pintado + rechazo de toques).
- Modify: `README.md` — nota de render consciente del espacio en la sección BoardSpace.
- Modify: `AI_HISTORY.MD` — entradas 086 y 087.

---

### Task 0: Rama y commit del plan

**Files:**
- Create branch: `feat/#87-space-aware-render` (desde `main` actualizado; usar worktree vía superpowers:using-git-worktrees si se ejecuta con subagentes)
- Commit: `docs/superpowers/plans/2026-07-15-front87-space-aware-render.md` (este archivo)

- [ ] **Step 1: Crear la rama desde main actualizado**

```bash
git checkout main && git pull && git checkout -b "feat/#87-space-aware-render"
```

- [ ] **Step 2: Commit del plan**

```bash
git add docs/superpowers/plans/2026-07-15-front87-space-aware-render.md
git commit -m "docs(plan): add front#87 space-aware board render plan"
```

---

### Task 1: `BoardSurfacePainter` — pintar el panel a través del espacio

**Files:**
- Create: `lib/presentation/game/painters/board_surface_painter.dart`
- Test: `test/presentation/game/painters/board_surface_painter_test.dart`
- Modify: `AI_HISTORY.MD` (Entrada 086)

**Interfaces:**
- Consumes: `BoardSpace` (`space.bounds`, `space.contains`), `BoundingBox` (`minRow/minCol/rows/cols/maxRow/maxCol/isEmpty`), `Position(row:, col:)` — todo ya en main (#85).
- Produces: `BoardSurfacePainter({required BoardSpace space, required double cell, required Color surfaceColor, required Color gridColor, Rect? visibleRect})` — `CustomPainter` que la Task 2 monta en un `Positioned.fill > CustomPaint`. El canvas se asume en coordenadas del marco (origen = esquina del bounding box) y con tamaño `bounds.cols*cell × bounds.rows*cell`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/presentation/game/painters/board_surface_painter_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/game_core/space/board_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';

import '../../../support/holed_rect_space.dart';

const _surface = Color(0xFF223344);
const _grid = Color(0x1A99AABB);

BoardSurfacePainter _painter(BoardSpace space, {double cell = 10, Rect? visibleRect}) =>
    BoardSurfacePainter(
      space: space,
      cell: cell,
      surfaceColor: _surface,
      gridColor: _grid,
      visibleRect: visibleRect,
    );

/// Monta el painter en un CustomPaint del tamaño exacto del tablero y
/// devuelve su RenderObject para los matchers de canvas (`paints`).
Future<RenderObject> _pump(
  WidgetTester tester,
  BoardSurfacePainter painter, {
  required double width,
  required double height,
}) async {
  await tester.pumpWidget(Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: painter),
    ),
  ));
  return tester.renderObject(find.byType(CustomPaint));
}

void main() {
  group('caja llena (RectSpace) — regresión píxel del render previo a #87', () {
    testWidgets('pinta UN panel redondeado + líneas de rejilla completas',
        (tester) async {
      // Arrange — 4×4, cell 25 → tablero 100×100, radio 25*0.35 = 8.75
      final render = await _pump(tester, _painter(RectSpace(4, 4), cell: 25),
          width: 100, height: 100);

      // Assert — panel único redondeado, sin rellenos por celda
      expect(
        render,
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 0, 100, 100),
              const Radius.circular(25 * 0.35),
            ),
          ),
      );
      // (cols-1) + (rows-1) = 3 + 3 líneas interiores
      expect(render, paintsExactlyCountTimes(#drawLine, 6));
      expect(render, isNot(paints..rect()));
    });
  });

  group('espacio enmascarado (HoledRectSpace) — solo celdas existentes', () {
    // 3×3 con agujero en (1,1), cell 10 → tablero 30×30.
    // OJO: HoledRectSpace NO resta el agujero de allCells/cellCount (doble de
    // certificación); el painter debe discriminar por `contains`, no por conteo.
    final holed = HoledRectSpace(3, 3, holes: {Position(row: 1, col: 1)});

    testWidgets('rellena las 8 celdas existentes y NO el agujero', (tester) async {
      // Arrange / Act
      final render =
          await _pump(tester, _painter(holed), width: 30, height: 30);

      // Assert
      expect(render, paintsExactlyCountTimes(#drawRect, 8));
      expect(render, paints..rect(rect: const Rect.fromLTWH(0, 0, 10, 10)));
      expect(render,
          isNot(paints..rect(rect: const Rect.fromLTWH(10, 10, 10, 10))));
      expect(render, isNot(paints..rrect()));
    });

    testWidgets('la rejilla solo existe entre dos celdas existentes', (tester) async {
      // Arrange / Act
      final render =
          await _pump(tester, _painter(holed), width: 30, height: 30);

      // Assert — 12 aristas interiores del 3×3 menos las 4 que tocan el agujero
      expect(render, paintsExactlyCountTimes(#drawLine, 8));
    });

    testWidgets('culling: con encuadre de la primera columna solo pinta esas celdas',
        (tester) async {
      // Arrange — encuadre que cubre solo la columna 0 (x ∈ [0,10])
      final render = await _pump(
        tester,
        _painter(holed, visibleRect: const Rect.fromLTWH(0, 0, 10, 30)),
        width: 30,
        height: 30,
      );

      // Assert — (0,0), (1,0), (2,0): 3 rellenos
      expect(render, paintsExactlyCountTimes(#drawRect, 3));
    });
  });

  group('shouldRepaint', () {
    test('true si cambia el espacio; false si es equivalente por valor', () {
      // Arrange
      final a = _painter(RectSpace(3, 3));
      final b = _painter(RectSpace(3, 3));
      final c = _painter(HoledRectSpace(3, 3, holes: {Position(row: 0, col: 0)}));

      // Act / Assert — BoardSpace es Equatable: igualdad por valor
      expect(a.shouldRepaint(b), isFalse);
      expect(a.shouldRepaint(c), isTrue);
    });
  });
}
```

- [ ] **Step 2: Correr los tests y verificar que fallan**

Run: `flutter test test/presentation/game/painters/board_surface_painter_test.dart`
Expected: FAIL — error de compilación: `board_surface_painter.dart` no existe.

- [ ] **Step 3: Implementar el painter**

Crear `lib/presentation/game/painters/board_surface_painter.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../domain/game_core/space/board_space.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/position.dart';

/// Superficie del tablero consciente del espacio (Fase 1, front#87): pinta
/// panel y rejilla A TRAVÉS de [BoardSpace] en vez de asumir un rectángulo
/// cols×rows (reemplaza al par DecoratedBox + _GridPainter de BoardView).
///
/// Dos caminos:
///  - Caja llena (cada celda del bounding box existe — p. ej. RectSpace):
///    panel redondeado único + líneas de rejilla, píxel-idéntico al render
///    previo a #87. Es la garantía de regresión de la campaña.
///  - Espacio enmascarado: solo se rellenan las celdas que EXISTEN y cada
///    segmento de rejilla se dibuja únicamente entre dos celdas existentes
///    (una arista con celda ausente es frontera visual, como el borde).
///
/// La existencia se decide celda a celda con `contains` — NUNCA con
/// `allCells`/`cellCount`: el doble de certificación HoledRectSpace
/// deliberadamente no resta sus agujeros de esos miembros (ver test/support),
/// así que discriminar por conteo tomaría el camino equivocado.
///
/// El canvas está en coordenadas del MARCO (origen = esquina del bounding
/// box): la celda absoluta (row,col) se pinta en
/// ((col−minCol)·cell, (row−minRow)·cell). [visibleRect] (culling front#66)
/// llega en esas mismas coordenadas.
class BoardSurfacePainter extends CustomPainter {
  final BoardSpace space;
  final double cell;
  final Color surfaceColor;
  final Color gridColor;
  final Rect? visibleRect;

  const BoardSurfacePainter({
    required this.space,
    required this.cell,
    required this.surfaceColor,
    required this.gridColor,
    this.visibleRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frame = space.bounds;
    if (frame.isEmpty) return;
    if (_isFullBox(frame)) {
      _paintFullPanel(canvas, size, frame.cols, frame.rows);
    } else {
      _paintMaskedCells(canvas, frame);
    }
  }

  /// True si CADA celda del bounding box existe en el espacio. O(área de la
  /// caja) con `contains` O(1); a 50×50 son 2 500 chequeos por frame,
  /// despreciable frente al propio dibujo.
  bool _isFullBox(BoundingBox frame) {
    for (var r = 0; r < frame.rows; r++) {
      for (var c = 0; c < frame.cols; c++) {
        if (!space.contains(
            Position(row: frame.minRow + r, col: frame.minCol + c))) {
          return false;
        }
      }
    }
    return true;
  }

  /// Camino de caja llena: reproduce EXACTAMENTE el render previo a #87
  /// (DecoratedBox redondeado + _GridPainter con culling) para que la
  /// campaña rectangular no cambie ni un píxel.
  void _paintFullPanel(Canvas canvas, Size size, int cols, int rows) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.35)),
      Paint()..color = surfaceColor,
    );

    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final cw = size.width / cols;
    final ch = size.height / rows;
    final r = visibleRect;

    // Banda visible acotada al tablero; sin encuadre se pinta completo.
    final left = (r?.left ?? 0.0).clamp(0.0, size.width);
    final right = (r?.right ?? size.width).clamp(0.0, size.width);
    final top = (r?.top ?? 0.0).clamp(0.0, size.height);
    final bottom = (r?.bottom ?? size.height).clamp(0.0, size.height);

    // Solo las líneas verticales cuyo índice cae dentro del encuadre.
    final firstCol = r == null ? 1 : math.max(1, (left / cw).floor());
    final lastCol =
        r == null ? cols - 1 : math.min(cols - 1, (right / cw).ceil());
    for (var i = firstCol; i <= lastCol; i++) {
      canvas.drawLine(Offset(cw * i, top), Offset(cw * i, bottom), paint);
    }

    final firstRow = r == null ? 1 : math.max(1, (top / ch).floor());
    final lastRow =
        r == null ? rows - 1 : math.min(rows - 1, (bottom / ch).ceil());
    for (var j = firstRow; j <= lastRow; j++) {
      canvas.drawLine(Offset(left, ch * j), Offset(right, ch * j), paint);
    }
  }

  /// Camino enmascarado: relleno por celda existente y rejilla SOLO entre dos
  /// celdas existentes. Cada arista interior se dibuja una vez (la derecha y
  /// la inferior de su celda dueña).
  void _paintMaskedCells(Canvas canvas, BoundingBox frame) {
    final fill = Paint()..color = surfaceColor;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Banda visible en índices de celda del marco (culling front#66); sin
    // encuadre se recorre la caja completa.
    final r = visibleRect;
    final firstCol = r == null ? 0 : math.max(0, (r.left / cell).floor());
    final lastCol = r == null
        ? frame.cols - 1
        : math.min(frame.cols - 1, (r.right / cell).ceil() - 1);
    final firstRow = r == null ? 0 : math.max(0, (r.top / cell).floor());
    final lastRow = r == null
        ? frame.rows - 1
        : math.min(frame.rows - 1, (r.bottom / cell).ceil() - 1);

    bool exists(int row, int col) => space.contains(
        Position(row: frame.minRow + row, col: frame.minCol + col));

    for (var row = firstRow; row <= lastRow; row++) {
      for (var col = firstCol; col <= lastCol; col++) {
        if (!exists(row, col)) continue;
        final rect = Rect.fromLTWH(col * cell, row * cell, cell, cell);
        canvas.drawRect(rect, fill);
        if (exists(row, col + 1)) {
          canvas.drawLine(rect.topRight, rect.bottomRight, grid);
        }
        if (exists(row + 1, col)) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, grid);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardSurfacePainter old) =>
      old.space != space ||
      old.cell != cell ||
      old.surfaceColor != surfaceColor ||
      old.gridColor != gridColor ||
      old.visibleRect != visibleRect;
}
```

- [ ] **Step 4: Correr los tests y verificar que pasan**

Run: `flutter test test/presentation/game/painters/board_surface_painter_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Registrar AI_HISTORY (Entrada 086) y commit**

Añadir al final de `AI_HISTORY.MD`:

```markdown
## Entrada 086 — BoardSurfacePainter consciente del espacio (front#87, Fase 1)

**Fecha:** 2026-07-15
**Tarea o problema abordado:** El panel+rejilla del tablero se pintaba como rectángulo fijo (DecoratedBox + _GridPainter), bloqueando siluetas. Se crea BoardSurfacePainter con camino de caja llena (píxel-idéntico) y camino enmascarado (solo celdas existentes vía `contains`, rejilla solo entre vecinas existentes).
**Herramienta de IA utilizada:** Claude Code (Fable 5)
**Prompt o instrucción proporcionada:** > "Tomemos el 87 y realicemos un plan para su implementación" (ejecución del plan docs/superpowers/plans/2026-07-15-front87-space-aware-render.md, Task 1)
**Resultado obtenido:** lib/presentation/game/painters/board_surface_painter.dart + 5 tests de canvas (paints/paintsExactlyCountTimes). Decisión clave: discriminar caja llena recorriendo `contains` sobre el bounding box — `cellCount` mentiría con HoledRectSpace (no resta agujeros por diseño).
**Modificaciones realizadas por el equipo:** (completar manualmente)
```

```bash
git add lib/presentation/game/painters/board_surface_painter.dart test/presentation/game/painters/board_surface_painter_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add space-aware BoardSurfacePainter"
```

---

### Task 2: `BoardView` — dimensionar, pintar y hit-testear vía el espacio

**Files:**
- Modify: `lib/presentation/game/widgets/board_widget.dart` (reemplazo completo del archivo, abajo)
- Test: `test/presentation/game/widgets/board_view_masked_space_test.dart` (nuevo)
- Modify: `README.md` (nota en la sección BoardSpace)
- Modify: `AI_HISTORY.MD` (Entrada 087)

**Interfaces:**
- Consumes: `BoardSurfacePainter` (Task 1, firma exacta de su constructor); `state.board.space` (`BoardSpace`), `space.bounds` (`BoundingBox`), `space.contains(Position)`.
- Produces: `BoardView` conserva su API pública (`state`, `onTapArrow`, `colorResolver`) — `GeneratedBoardWidget` y `BoardWidget` no se tocan. `_GridPainter` desaparece.

- [ ] **Step 1: Escribir los tests de widget que fallan**

Crear `test/presentation/game/widgets/board_view_masked_space_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/board_surface_painter.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import '../../../support/arrow_fixtures.dart';
import '../../../support/holed_rect_space.dart';

/// Tablero 3×3 con agujero en (1,1) y dos flechas:
///   arrow-top:  celdas (0,0)-(0,1) — sobre celdas existentes
///   arrow-hole: celda (1,1) — PATOLÓGICA, montada sobre el agujero a
///   propósito: si el toque llegara a arrowAt, la encontraría. Prueba que el
///   rechazo ocurre por `space.contains` ANTES de resolver la flecha.
ArrowBoard _maskedBoard() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('arrow-top'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        straightArrow(
          id: const ArrowId('arrow-hole'),
          tail: Position(row: 1, col: 1),
          direction: Direction.right,
          length: 1,
        ),
      ],
      space: HoledRectSpace(3, 3, holes: {Position(row: 1, col: 1)}),
    );

/// Monta un BoardView PURO (sin providers) en 300×300 → cell = 100.
/// Devuelve la lista donde se acumulan los taps enrutados.
Future<List<ArrowId>> _pumpMasked(WidgetTester tester) async {
  final taps = <ArrowId>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 300,
        child: BoardView(
          state: GamePlaying(board: _maskedBoard(), moves: const MoveCount(0)),
          onTapArrow: taps.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return taps;
}

Finder _surfacePaint() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is BoardSurfacePainter);

void main() {
  testWidgets('la superficie se pinta a través del ESPACIO del board',
      (tester) async {
    // Arrange / Act
    await _pumpMasked(tester);

    // Assert — el painter recibe el space del board (no dims sueltas) y, a
    // nivel de widget, solo rellena las 8 celdas existentes (cell = 100).
    final paint = tester.widget<CustomPaint>(_surfacePaint());
    expect((paint.painter! as BoardSurfacePainter).space,
        HoledRectSpace(3, 3, holes: {Position(row: 1, col: 1)}));
    expect(tester.renderObject(_surfacePaint()),
        paintsExactlyCountTimes(#drawRect, 8));
  });

  testWidgets('un toque sobre una celda que NO existe se rechaza aunque haya flecha',
      (tester) async {
    // Arrange
    final taps = await _pumpMasked(tester);

    // Act — centro de la celda (1,1), el agujero, donde vive arrow-hole
    await tester.tapAt(const Offset(150, 150));
    await tester.pump();

    // Assert — space.contains veta el toque antes de arrowAt
    expect(taps, isEmpty);
  });

  testWidgets('un toque sobre una celda existente enruta a su flecha',
      (tester) async {
    // Arrange
    final taps = await _pumpMasked(tester);

    // Act — centro de la celda (0,0), cuerpo de arrow-top
    await tester.tapAt(const Offset(50, 50));
    await tester.pump();

    // Assert
    expect(taps, [const ArrowId('arrow-top')]);
  });
}
```

- [ ] **Step 2: Correr los tests nuevos y verificar que fallan**

Run: `flutter test test/presentation/game/widgets/board_view_masked_space_test.dart`
Expected: FAIL — no existe ningún `CustomPaint` con `BoardSurfacePainter` (test 1) y el toque en (150,150) SÍ enruta a `arrow-hole` (test 2).

- [ ] **Step 3: Reescribir `board_widget.dart`**

Reemplazar el contenido COMPLETO de `lib/presentation/game/widgets/board_widget.dart` por:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/arrows/value_objects/arrow_id.dart';
import '../../../domain/game_core/space/bounding_box.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../../application/state/game_controller.dart';
import '../arrow_color_resolver.dart';
import '../painters/board_surface_painter.dart';
import 'arrow_widget.dart';
import 'board_viewport.dart';
import 'exiting_arrow_widget.dart';

/// Rejilla del tablero: panel dimensionado por el bounding box del ESPACIO con
/// una flecha por `Positioned` (su bounding box). El hit-testing es POR CELDA
/// mediante un único GestureDetector (a prueba de forma: recta o doblada) —
/// esto resuelve el bug de "no se sabe qué flecha se toca". Consume el estado
/// vía gameControllerProvider.
class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).valueOrNull;
    if (state is! GamePlaying) return const SizedBox.shrink();
    return BoardView(
      state: state,
      colorResolver: ref.watch(arrowColorResolverProvider),
      onTapArrow: (id) =>
          ref.read(gameControllerProvider.notifier).tapArrow(id),
    );
  }
}

/// Vista presentacional PURA del tablero: recibe el [GamePlaying] y el callback
/// de toque, sin conocer QUÉ controlador lo alimenta. La extrae de [BoardWidget]
/// para que el flujo de tableros generados (front#37) reutilice exactamente el
/// mismo render y hit-testing enganchando su propio controlador, manteniendo
/// una única fuente de la lógica de dibujo (DRY).
class BoardView extends StatelessWidget {
  final GamePlaying state;
  final void Function(ArrowId arrowId) onTapArrow;

  /// Seam de color (front#67): decide el Color de cada flecha. Default temático
  /// que cae a identidad sin Instrucciones de pintado, así los call sites que no
  /// lo inyectan (flujo generado, tests) pintan igual que antes. [BoardWidget] lo
  /// inyecta desde `arrowColorResolverProvider`.
  final ArrowColorResolver colorResolver;

  const BoardView({
    super.key,
    required this.state,
    required this.onTapArrow,
    this.colorResolver = const ThemedArrowColorResolver(),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final gridColor = (isDark
            ? AppColors.onSurfaceMuted
            : AppColors.lightOnSurfaceMuted)
        .withValues(alpha: 0.10);

    // front#87: el tablero se dimensiona por la caja envolvente del ESPACIO —
    // qué celdas existen dentro de ella lo deciden el painter y el hit-testing
    // con space.contains, no una suposición rectangular.
    final frame = state.board.space.bounds;
    if (frame.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math.min(
          constraints.maxWidth / frame.cols,
          constraints.maxHeight / frame.rows,
        );
        final width = frame.cols * cell;
        final height = frame.rows * cell;

        // front#66: la cámara (zoom/pan + doble-tap) envuelve el tablero ya
        // ajustado a "fit" y alimenta el rectángulo visible para el culling.
        return BoardViewport(
          viewportSize: Size(constraints.maxWidth, constraints.maxHeight),
          boardSize: Size(width, height),
          builder: (visibleRect) => _boardContent(
            context: context,
            cell: cell,
            surface: surface,
            gridColor: gridColor,
            visibleRect: visibleRect,
          ),
        );
      },
    );
  }

  Widget _boardContent({
    required BuildContext context,
    required double cell,
    required Color surface,
    required Color gridColor,
    required Rect? visibleRect,
  }) {
    final board = state.board;
    final space = board.space;
    // Marco del tablero (front#87): el canvas y los Positioned trabajan con
    // origen en la esquina del bounding box (celda absoluta − frame.min…), así
    // un espacio recortado (min ≠ 0) renderiza sin reescribir las celdas de
    // sus flechas. Con los espacios actuales (origen 0) es la identidad.
    final frame = space.bounds;
    // Margen de culling: mantiene construidas las flechas que apenas rozan el
    // borde del encuadre para que no aparezcan "de golpe" al hacer pan.
    final camera = visibleRect?.inflate(cell * 2);

    bool onCamera(Arrow arrow) {
      if (camera == null) return true;
      final b = _bounds(arrow);
      final rect = Rect.fromLTWH(
        (b.minCol - frame.minCol) * cell,
        (b.minRow - frame.minRow) * cell,
        (b.maxCol - b.minCol + 1) * cell,
        (b.maxRow - b.minRow + 1) * cell,
      );
      return camera.overlaps(rect);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        // front#87: el marco solo DIMENSIONA; la existencia de cada celda la
        // decide el espacio. Un toque sobre una celda que no existe se rechaza
        // antes de resolver flecha alguna.
        final pos = Position(
          row: ((details.localPosition.dy / cell).floor() + frame.minRow)
              .clamp(frame.minRow, frame.maxRow),
          col: ((details.localPosition.dx / cell).floor() + frame.minCol)
              .clamp(frame.minCol, frame.maxCol),
        );
        if (!space.contains(pos)) return;
        final arrow = board.arrowAt(pos);
        if (arrow != null) {
          onTapArrow(arrow.id);
        }
      },
      child: Stack(
        clipBehavior: Clip.none, // la flecha saliente cruza el borde
        children: [
          // front#87: panel + rejilla se pintan A TRAVÉS del espacio (solo
          // celdas existentes); con caja llena el painter reproduce el panel
          // redondeado previo píxel a píxel.
          Positioned.fill(
            child: CustomPaint(
              painter: BoardSurfacePainter(
                space: space,
                cell: cell,
                surfaceColor: surface.withValues(alpha: 0.30),
                gridColor: gridColor,
                visibleRect: visibleRect,
              ),
            ),
          ),
          // Culling de flechas: solo se construyen (con su AnimationController)
          // las que caen dentro de la cámara. Fuera de zoom, el encuadre cubre
          // todo el tablero, así que se construyen todas (comportamiento previo).
          for (final arrow in board.arrows)
            if (onCamera(arrow)) _positionArrow(arrow, cell, state, frame),
          // La flecha saliente es una animación transitoria que cruza el borde:
          // siempre se dibuja mientras dure, aunque su celda de origen ya no esté.
          if (state.exitingArrow != null)
            _positionExiting(state.exitingArrow!, cell, state.exitNonce, frame),
        ],
      ),
    );
  }

  ({int minCol, int minRow, int maxCol, int maxRow}) _bounds(Arrow arrow) {
    var minCol = arrow.cells.first.col;
    var maxCol = arrow.cells.first.col;
    var minRow = arrow.cells.first.row;
    var maxRow = arrow.cells.first.row;
    for (final p in arrow.cells) {
      minCol = math.min(minCol, p.col);
      maxCol = math.max(maxCol, p.col);
      minRow = math.min(minRow, p.row);
      maxRow = math.max(maxRow, p.row);
    }
    return (minCol: minCol, minRow: minRow, maxCol: maxCol, maxRow: maxRow);
  }

  Widget _positionArrow(
      Arrow arrow, double cell, GamePlaying state, BoundingBox frame) {
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

  Widget _positionExiting(
      Arrow arrow, double cell, int nonce, BoundingBox frame) {
    final b = _bounds(arrow);
    return Positioned(
      left: (b.minCol - frame.minCol) * cell,
      top: (b.minRow - frame.minRow) * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      // Limitación conocida (front#87): el recorrido de salida se calcula
      // contra el marco cols×rows anclado en origen (cellsToEdge); en un
      // espacio enmascarado la animación cruza las celdas ausentes hasta el
      // borde de la caja. Cosmético — se revisa con front#88 si molesta.
      child: ExitingArrowWidget(
        key: ValueKey('exiting-$nonce'),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cols: frame.cols,
        rows: frame.rows,
        cell: cell,
        color: colorResolver.colorFor(arrow, state.palette),
        nonce: nonce,
      ),
    );
  }
}
```

Notas del cambio (para el implementador):
- `_GridPainter` se ELIMINA por completo (su lógica vive ahora en el camino de caja llena de `BoardSurfacePainter`).
- `ArrowWidget` sigue recibiendo `minCol`/`minRow` ABSOLUTOS (los usa solo para offsets internos relativos a su propia caja — invariantes ante la traslación).
- `BoardWidget` y la API pública de `BoardView` no cambian: `GeneratedBoardWidget` queda cubierto sin tocarlo.

- [ ] **Step 4: Correr los tests nuevos y los existentes del widget**

Run: `flutter test test/presentation/game/widgets/`
Expected: PASS — los 3 tests nuevos y los 3 existentes de `board_widget_test.dart` (regresión RectSpace) en verde.

- [ ] **Step 5: Correr la suite completa**

Run: `flutter test`
Expected: PASS — 647 preexistentes + 8 nuevos (5 painter + 3 widget). Ningún test existente editado.

- [ ] **Step 6: Nota en README**

En `MazePruebaFront/README.md`, dentro de la sección que documenta BoardSpace (añadida por front#73), agregar al final:

```markdown
- **Render consciente del espacio (front#87)**: `BoardView` dimensiona, pinta y hace hit-testing a través de `BoardSpace` (`space.bounds` + `contains`), no de un rectángulo `cols×rows`. `BoardSurfacePainter` pinta el panel redondeado completo (píxel-idéntico al render previo) cuando el espacio llena su bounding box, y solo las celdas existentes —con rejilla únicamente entre celdas vecinas existentes— cuando el espacio está enmascarado. Los toques sobre celdas que no existen se rechazan antes de resolver la flecha.
```

- [ ] **Step 7: Registrar AI_HISTORY (Entrada 087) y commit**

Añadir al final de `AI_HISTORY.MD`:

```markdown
## Entrada 087 — BoardView renderiza y hit-testea vía BoardSpace (front#87, Fase 1)

**Fecha:** 2026-07-15
**Tarea o problema abordado:** BoardView asumía un rectángulo cols×rows (panel Positioned.fill + _GridPainter + hit-test clampeado), bloqueando siluetas. Ahora dimensiona por `space.bounds`, pinta con BoardSurfacePainter, rechaza toques sobre celdas inexistentes vía `space.contains` y trabaja en coordenadas del marco (origen = esquina del bounding box, listo para el recorte de front#88).
**Herramienta de IA utilizada:** Claude Code (Fable 5)
**Prompt o instrucción proporcionada:** > "Tomemos el 87 y realicemos un plan para su implementación" (ejecución del plan docs/superpowers/plans/2026-07-15-front87-space-aware-render.md, Task 2)
**Resultado obtenido:** board_widget.dart reescrito (muere _GridPainter), 3 tests de widget con HoledRectSpace (pintado solo de celdas existentes; rechazo del toque ANTES de arrowAt — probado con flecha patológica sobre el agujero), regresión RectSpace verde sin editar tests. Limitación documentada: la animación de salida cruza celdas ausentes hasta el borde de la caja (cosmético, revisar con front#88).
**Modificaciones realizadas por el equipo:** (completar manualmente)
```

```bash
git add lib/presentation/game/widgets/board_widget.dart test/presentation/game/widgets/board_view_masked_space_test.dart README.md AI_HISTORY.MD
git commit -m "refactor(presentation): render and hit-test the board via BoardSpace"
```

---

### Task 3: Verificación final y PR

**Files:** ninguno nuevo — verificación, push y PR.

- [ ] **Step 1: Análisis estático**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Suite completa (confirmación final)**

Run: `flutter test`
Expected: PASS total (655 = 647 + 8). Si algo falla, arreglar ANTES de abrir el PR — nunca abrirlo en rojo.

- [ ] **Step 3: Push y PR**

```bash
git push -u origin "feat/#87-space-aware-render"
gh pr create --title "refactor(presentation): render y hit-test del tablero vía BoardSpace (front#87)" --body "$(cat <<'EOF'
Closes #87 (Fase 1).

## Qué cambia
- Nuevo `BoardSurfacePainter`: panel+rejilla pintados A TRAVÉS de `BoardSpace`. Caja llena → render previo píxel-idéntico (regresión campaña); enmascarado → solo celdas existentes, rejilla solo entre vecinas existentes.
- `BoardView`: dimensiona por `space.bounds`, hit-test rechaza celdas inexistentes vía `space.contains` ANTES de `arrowAt`, coordenadas trasladadas al marco (origen = esquina del bounding box → front#88 puede recortar sin reescribir celdas). Muere `_GridPainter`.
- `GeneratedBoardWidget` queda cubierto sin tocarlo (wrapper fino sobre `BoardView`).

## Decisiones
- Discriminador de caja llena = `contains` sobre toda la caja, NO `cellCount`: `HoledRectSpace` (doble de certificación) no resta agujeros de `allCells`/`cellCount` por diseño.
- Limitación documentada: la animación de salida (`cellsToEdge`, marco anclado en origen) cruza celdas ausentes hasta el borde de la caja en espacios enmascarados. Cosmético; se revisa con front#88.
- Celdas enmascaradas se rellenan como cuadrados (sin esquinas redondeadas por celda) — estética de silueta, ajustable después si se quiere.

## Tests
- 5 unit del painter (canvas: rrect único + 6 líneas en caja llena; 8 rects/8 segmentos con agujero en (1,1); culling por banda; shouldRepaint por valor).
- 3 widget con `HoledRectSpace` vía `BoardView` puro (painter recibe el space; toque sobre celda inexistente rechazado aunque haya flecha patológica encima; toque sobre celda existente enruta).
- Suite completa verde sin editar tests existentes; `flutter analyze` limpio.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: URL del PR. **El usuario decide el merge** — no mergear.

---

## Self-Review (hecho al escribir el plan)

- **Cobertura del issue**: dimensionar por bounds (Task 2 build), pintar solo celdas existentes (Task 1), hit-test vía contains (Task 2), culling/viewport intacto (painter recibe visibleRect + onCamera trasladado; BoardViewport sin tocar), regresión RectSpace (camino caja llena portado literal + suite sin editar), test de widget enmascarado (Task 2 Step 1), analyze limpio (Task 3). Out of scope respetado: sin `bounds` nuevos en dominio (#85 ya mergeado), sin derivación de máscara temática (#88).
- **Tipos consistentes**: `BoardSurfacePainter(space:, cell:, surfaceColor:, gridColor:, visibleRect:)` idéntico en Task 1 (definición), Task 1 tests, Task 2 widget y Task 2 tests. `_positionArrow/_positionExiting` reciben `BoundingBox frame`.
- **Trampas señaladas**: `HoledRectSpace.cellCount` miente (por eso `_isFullBox` recorre `contains`); `ArrowWidget` conserva `minCol/minRow` absolutos; flecha patológica sobre el agujero prueba el orden contains→arrowAt.
