# Arrow Maze — Port Visual del Tablero (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portar los visuales y animaciones de `app-agentic-sprint` a `feat/main-sprint` (flechas con cuerpo grueso multicolor, hit-testing por celda, shake/slide-out, pantallas pulidas) y habilitar tableros escalados por nivel, conservando la Clean Mobile Architecture actual.

**Architecture:** `domain/` puro (Dart sin Flutter) → `application/` (Riverpod Notifiers + use cases + commands) → `presentation/` (screens/widgets/painters que solo consumen `application/`). El color es responsabilidad de presentación; el dominio no lo conoce. Render e hit-testing son agnósticos de la forma (consumen `arrow.cells`), habilitando flechas dobladas en el futuro sin reescribir UI.

**Tech Stack:** Flutter SDK (Dart), `flutter_riverpod`, `dartz` (Either), `equatable`, Hive CE (persistencia), `flutter_test` + `mockito` + `build_runner` (tests/mocks).

**Spec de referencia:** `docs/superpowers/specs/2026-06-18-arrowmaze-visual-port-design.md` (léelo antes de empezar; este plan lo implementa fielmente).

## Global Constraints

- **Regla de dependencias:** `domain/` NO importa Flutter ni packages externos (salvo `equatable`/`dartz` ya usados). `presentation/` NUNCA importa `infrastructure/` ni llama directo a `domain/` para lógica — consume `application/` (excepción permitida: tipos de dominio como `Arrow`, `ArrowId`, `Position`, `Direction`, `LevelId` para render/navegación, igual que hoy).
- **Color en presentación:** ninguna entidad de dominio recibe color/`colorIndex`. El color por flecha se deriva de `ArrowId` en presentación.
- **Tema dual:** se conservan `AppTheme.light()` y `AppTheme.dark()` con `ThemeMode.system` en `main.dart`. Los widgets eligen color por `Theme.of(context).brightness`.
- **Copy en español** en TODA la UI (títulos, taglines, botones).
- **Navegación:** rutas nombradas vía `AppRouter` (no `MaterialPageRoute`).
- **Render/hit-testing agnósticos de forma:** painter y board widget dependen solo de `arrow.cells` + orientación de la punta; el hit-testing es por celda (`ArrowBoard.arrowAt`).
- **Tests AAA:** Arrange-Act-Assert, mocks para aislar la unidad. Mocks con `@GenerateMocks` + `dart run build_runner build --delete-conflicting-outputs`.
- **Comandos del proyecto:** `flutter test` (todos), `flutter test <ruta>` (uno), `flutter analyze` (lint), `dart run build_runner build --delete-conflicting-outputs` (codegen).
- **Proceso de commits (en EJECUCIÓN, no ahora):** cada Task termina con (a) una entrada en `MazePruebaFront/AI_HISTORY.MD` siguiendo la plantilla de CLAUDE.md y (b) un commit Conventional Commits (`<tipo>(front[/ámbito]): <descripción>`). **Durante la escritura de este plan NO se commitea ni se toca `AI_HISTORY.MD`** (instrucción explícita del usuario). El usuario decide cuándo arranca la ejecución.
- **Sin placeholders:** todo el código de cada step es real y aplicable.

---

## Estructura de archivos (qué toca cada fase)

| Archivo | Tipo | Responsabilidad | Fase |
|---|---|---|---|
| `lib/core/theme/app_colors.dart` | Mod | Paleta jewel dual + `arrowPalette`/`arrowColor()`; elimina color por dirección | 1 |
| `lib/core/theme/app_theme.dart` | Mod | Alimenta `ColorScheme` claro/oscuro con la paleta nueva | 1 |
| `lib/presentation/game/arrow_color.dart` | New | `arrowColorIndex(ArrowId)` + `arrowColorFor(ArrowId)` (color estable por flecha) | 1 |
| `lib/domain/arrows/entities/arrow_board.dart` | Mod | Queries puras `arrowAt(Position)` y `arrowById(ArrowId)` | 2 |
| `lib/domain/board/value_objects/level_id.dart` | Mod | `int get number` (parse con fallback 1) | 2 |
| `lib/domain/board/value_objects/level_blueprint.dart` | New | Curva de dificultad `LevelBlueprint.forLevel(int)` | 2 |
| `lib/domain/arrows/services/i_level_generator.dart` | Mod | Puerto `generate({cols, rows, arrowCount, int? seed})` | 3 |
| `lib/infrastructure/generators/graph_board_generator.dart` | Mod | `seed` por nivel; longitud mín. 2; `maxAttempts` escalado; degradación logueada | 3 |
| `lib/application/commands/command_invoker.dart` | Mod | `clear()` para restart | 4 |
| `lib/application/state/game_state.dart` | Mod | `GamePlaying` con campos transitorios + `canUndo` | 4 |
| `lib/application/state/game_controller.dart` | Mod | `loadLevel` con blueprint+seed; `tapArrow` con feedback; `restartLevel`; `canUndo` | 4 |
| `lib/presentation/game/painters/arrow_painter.dart` | Mod | Painter por polilínea (cuerpo grueso + glow + punta), coords locales | 5 |
| `lib/presentation/game/widgets/arrow_widget.dart` | Mod | `StatefulWidget` render puro + shake (sin gesto) | 5 |
| `lib/presentation/game/widgets/exiting_arrow_widget.dart` | Mod | Overlay auto-desmontable keyed por `exitNonce` (slide+fade) | 5 |
| `lib/presentation/game/widgets/board_widget.dart` | Mod | `LayoutBuilder` + rejilla + `Positioned` por bbox + hit-testing por celda + overlay salida | 5 |
| `lib/core/router/app_router.dart` | Mod | Args de la ruta victoria (`levelId`+`moves`) | 6 |
| `lib/presentation/home/screens/home_screen.dart` | Mod | Rediseño + logo animado + copy ES | 6 |
| `lib/presentation/game/screens/game_screen.dart` | Mod | Top bar custom + AnimatedSwitcher + restart | 6 |
| `lib/presentation/level_selection/victory_screen.dart` | Mod | Rediseño won view (recibe levelId+moves) | 6 |
| `lib/presentation/level_selection/level_selection_screen.dart` | Mod | Re-tematizado + copy ES | 6 |

**Tests nuevos:** `test/presentation/arrow_color_test.dart` (F1), `test/domain/arrow_board_test.dart` + `test/domain/level_id_test.dart` + `test/domain/level_blueprint_test.dart` (F2), `test/infrastructure/graph_board_generator_test.dart` (F3), `test/application/command_invoker_test.dart` + `test/application/game_controller_test.dart` (F4), `test/presentation/board_widget_hit_test.dart` (F5).

---

## Índice de fases

1. **Fase 1 — Fundación de tema y color** (sin cambios de comportamiento): paleta jewel dual, helper de color por flecha.
2. **Fase 2 — Dominio: queries y dificultad**: `arrowAt`/`arrowById`, `LevelId.number`, `LevelBlueprint`.
3. **Fase 3 — Generación escalada por nivel**: puerto con `seed`, generador determinista/robusto.
4. **Fase 4 — Estado de aplicación**: `CommandInvoker.clear`, `GamePlaying` extendido, `GameController` (blueprint, feedback, restart).
5. **Fase 5 — Render del tablero**: painter por polilínea, arrow_widget (shake), exiting_arrow_widget, board_widget (hit-testing por celda).
6. **Fase 6 — Pantallas y navegación**: router, home, game_screen, victory, level_selection.

> Orden de dependencias: 1 y 2 son independientes; 3 depende de 2; 4 depende de 2-3; 5 depende de 1-2-4; 6 depende de 4-5.

---

## Fase 1 — Fundación de tema y color

Objetivo: dejar la paleta y el color-por-flecha listos antes de tocar render. No cambia comportamiento de juego. Al terminar, `flutter analyze` limpio y los tests de color en verde.

### Task 1.1: Paleta `AppColors` (jewel, dual) + helper `arrowColor`

**Files:**
- Modify: `lib/core/theme/app_colors.dart` (reescritura del contenido de la clase)
- Test: `test/presentation/arrow_color_test.dart` (se crea aquí el archivo; cubre `arrowColor` y, en Task 1.3, `arrowColorIndex`)

**Interfaces:**
- Produces:
  - `AppColors.background/backgroundDeep/surface/pill/onBackground/onSurfaceMuted/primary/secondary/victory` (dark)
  - `AppColors.lightBackground/lightBackgroundDeep/lightSurface/lightPill/lightOnBackground/lightOnSurfaceMuted/lightPrimary/lightSecondary` (light)
  - `AppColors.glassFill/glassBorder/lightGlassFill/lightGlassBorder` (se conservan)
  - `AppColors.success/warning/error` (se conservan)
  - `static const List<Color> arrowPalette` (8 tonos)
  - `static Color arrowColor(int index) => arrowPalette[index % arrowPalette.length];`
  - Se ELIMINAN `arrowUp/arrowDown/arrowLeft/arrowRight/arrowHighlight`.

- [ ] **Step 1: Escribir el test que falla** (color wrap-around)

Crear `test/presentation/arrow_color_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';

void main() {
  group('AppColors.arrowColor', () {
    test('mapea índices dentro de rango a su color de paleta', () {
      // Arrange / Act / Assert
      expect(AppColors.arrowColor(0), AppColors.arrowPalette[0]);
      expect(AppColors.arrowColor(7), AppColors.arrowPalette[7]);
    });

    test('hace wrap-around módulo el tamaño de la paleta', () {
      expect(AppColors.arrowColor(8), AppColors.arrowPalette[0]);
      expect(AppColors.arrowColor(9), AppColors.arrowPalette[1]);
    });

    test('la paleta tiene 8 colores', () {
      expect(AppColors.arrowPalette.length, 8);
    });
  });
}
```

> Nota: el nombre del package en imports es `flutter_arrow_maze` (verificado en `MazePruebaFront/pubspec.yaml`, `name: flutter_arrow_maze`). Todos los imports de test de este plan ya usan ese prefijo.

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/arrow_color_test.dart`
Expected: FAIL — `arrowPalette`/`arrowColor` no existen aún.

- [ ] **Step 3: Reescribir `app_colors.dart`**

Reemplazar el contenido de la clase `AppColors` por:

```dart
import 'package:flutter/material.dart';

/// Paleta de Arrow Maze — índigo profundo + tonos joya maduros. Es la fuente
/// única de verdad de color; widgets y painters no hardcodean hex. El color
/// por flecha vive en presentación (ver arrow_color.dart), no en el dominio.
class AppColors {
  AppColors._();

  // --- Tema oscuro (protagonista) ---
  static const Color background = Color(0xFF0E1020);
  static const Color backgroundDeep = Color(0xFF070812);
  static const Color surface = Color(0xFF181B30);
  static const Color pill = Color(0xFF242843);
  static const Color onBackground = Color(0xFFE6E8F5);
  static const Color onSurfaceMuted = Color(0xFF7E84A8);
  static const Color primary = Color(0xFF5B6CC4); // seed / CTA
  static const Color secondary = Color(0xFF8A6FD0); // acento violeta (glow)
  static const Color victory = Color(0xFFE0B45A);

  static const Color glassBorder = Color(0x26FFFFFF); // blanco ~15%
  static const Color glassFill = Color(0x14FFFFFF); // blanco ~8%

  // Estado
  static const Color success = Color(0xFF46B98C);
  static const Color warning = Color(0xFFD7A24A);
  static const Color error = Color(0xFFCF646F);

  // --- Tema claro (contraparte) ---
  static const Color lightBackground = Color(0xFFF4F5FB);
  static const Color lightBackgroundDeep = Color(0xFFE7E9F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPill = Color(0xFFE7E9F5);
  static const Color lightOnBackground = Color(0xFF1B1E33);
  static const Color lightOnSurfaceMuted = Color(0xFF6B7095);
  static const Color lightPrimary = Color(0xFF4B5BB5);
  static const Color lightSecondary = Color(0xFF7C5FC0);

  static const Color lightGlassBorder = Color(0x14000000); // negro ~8%
  static const Color lightGlassFill = Color(0x0A000000); // negro ~4%

  // --- Paleta de flechas (tonos joya). Indexada por flecha desde presentación. ---
  static const List<Color> arrowPalette = <Color>[
    Color(0xFF46B98C), // esmeralda
    Color(0xFF39ACBE), // teal
    Color(0xFFD56C8E), // rosa
    Color(0xFFD7A24A), // ámbar
    Color(0xFFC9764E), // terracota
    Color(0xFF8A6FD0), // violeta
    Color(0xFF5E7AD0), // índigo
    Color(0xFFCF646F), // rojo apagado
  ];

  /// Resuelve el color de una flecha por índice (wrap-around módulo la paleta).
  static Color arrowColor(int index) =>
      arrowPalette[index % arrowPalette.length];
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/arrow_color_test.dart`
Expected: PASS (3 tests). Si falla por imports rotos en otros archivos (referencias a `arrowUp/Down/Left/Right`), es esperado — se corrigen en Fase 5; por ahora ejecuta solo este archivo de test.

- [ ] **Step 5: Commit** (en ejecución; ver Global Constraints)

```bash
git add lib/core/theme/app_colors.dart test/presentation/arrow_color_test.dart
git commit -m "refactor(front/theme): replace direction colors with jewel arrow palette"
```

---

### Task 1.2: `AppTheme` alimentado por la paleta nueva

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/presentation/arrow_color_test.dart` (se añade un grupo de smoke para AppTheme) — o un archivo nuevo `test/core/app_theme_test.dart` (usar este).

**Interfaces:**
- Consumes: `AppColors.*` (Task 1.1)
- Produces: `AppTheme.dark()` y `AppTheme.light()` → `ThemeData` con `scaffoldBackgroundColor` y `colorScheme` derivados de la paleta.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/core/app_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/core/theme/app_colors.dart';

void main() {
  test('AppTheme.dark usa el fondo oscuro de la paleta', () {
    final theme = AppTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });

  test('AppTheme.light usa el fondo claro de la paleta', () {
    final theme = AppTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/core/app_theme_test.dart`
Expected: FAIL si los colores anteriores ya no existen / valores cambian.

- [ ] **Step 3: Actualizar `app_theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Define los ThemeData claro y oscuro de Arrow Maze. El oscuro es el "hero"
/// (índigo profundo + tonos joya); el claro es su contraparte. `MaterialApp`
/// con `ThemeMode.system` selecciona según el sistema.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onBackground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onBackground,
      surface: AppColors.surface,
      onSurface: AppColors.onBackground,
      error: AppColors.error,
      onError: AppColors.background,
    );
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.lightPrimary,
      onPrimary: AppColors.lightSurface,
      secondary: AppColors.lightSecondary,
      onSecondary: AppColors.lightSurface,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightOnBackground,
      error: AppColors.error,
      onError: AppColors.lightSurface,
    );
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/core/app_theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart test/core/app_theme_test.dart
git commit -m "refactor(front/theme): feed ColorSchemes from the jewel palette"
```

---

### Task 1.3: Helper de color por flecha (presentación)

**Files:**
- Create: `lib/presentation/game/arrow_color.dart`
- Test: `test/presentation/arrow_color_test.dart` (añadir grupo `arrowColorIndex`)

**Interfaces:**
- Consumes: `ArrowId` (`lib/domain/arrows/value_objects/arrow_id.dart`), `AppColors.arrowColor` (Task 1.1)
- Produces:
  - `int arrowColorIndex(ArrowId id)` — índice estable desde `id.value` (parsea sufijo numérico de `arrow-N`; fallback `id.value.hashCode.abs()`), módulo `AppColors.arrowPalette.length`.
  - `Color arrowColorFor(ArrowId id) => AppColors.arrowColor(arrowColorIndex(id));`

- [ ] **Step 1: Escribir el test que falla** (añadir al final de `test/presentation/arrow_color_test.dart`, antes del cierre)

Añadir este grupo dentro de `main()`:

```dart
  group('arrowColorIndex', () {
    test('parsea el sufijo numérico de "arrow-N" en rango', () {
      expect(arrowColorIndex(const ArrowId('arrow-0')), 0);
      expect(arrowColorIndex(const ArrowId('arrow-3')), 3);
    });

    test('hace wrap-around con la paleta', () {
      expect(arrowColorIndex(const ArrowId('arrow-8')), 0);
      expect(arrowColorIndex(const ArrowId('arrow-10')), 2);
    });

    test('es estable: el mismo id devuelve siempre el mismo índice', () {
      final a = arrowColorIndex(const ArrowId('arrow-5'));
      final b = arrowColorIndex(const ArrowId('arrow-5'));
      expect(a, b);
    });

    test('fallback determinista para ids no numéricos', () {
      final i = arrowColorIndex(const ArrowId('weird-id'));
      expect(i, inInclusiveRange(0, 7));
    });
  });
```

Y añade los imports al inicio del archivo de test:

```dart
import 'package:flutter_arrow_maze/presentation/game/arrow_color.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/arrow_color_test.dart`
Expected: FAIL — `arrowColorIndex` no existe.

- [ ] **Step 3: Crear `arrow_color.dart`**

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';

/// Deriva un índice de color ESTABLE por flecha a partir de su [ArrowId].
///
/// El color es responsabilidad de presentación (el dominio no lo conoce). Los
/// ids generados tienen forma `arrow-N`: se parsea el sufijo para obtener un
/// arcoíris secuencial; si el id no es numérico se usa un hash determinista.
/// El índice es estable ante remociones (ligado a la identidad, no a la
/// posición en la lista de flechas).
int arrowColorIndex(ArrowId id) {
  final value = id.value;
  final dash = value.lastIndexOf('-');
  final suffix = dash >= 0 ? value.substring(dash + 1) : value;
  final parsed = int.tryParse(suffix);
  final base = parsed ?? value.hashCode.abs();
  return base % AppColors.arrowPalette.length;
}

/// Resuelve el [Color] de una flecha a partir de su [ArrowId].
Color arrowColorFor(ArrowId id) => AppColors.arrowColor(arrowColorIndex(id));
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/arrow_color_test.dart`
Expected: PASS (todos los grupos: `AppColors.arrowColor` + `arrowColorIndex`).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/game/arrow_color.dart test/presentation/arrow_color_test.dart
git commit -m "feat(front/presentation): add stable per-arrow color derivation"
```

---

> **Fin de Fase 1.** Verificación de fase: `flutter test test/presentation/arrow_color_test.dart test/core/app_theme_test.dart` en verde. (`flutter analyze` mostrará errores en archivos que aún referencian `arrowUp/Down/Left/Right`; se resuelven en Fase 5 — es esperado hasta entonces.)

---

## Fase 2 — Dominio: queries y dificultad

Objetivo: añadir las consultas puras del aggregate root que necesita el hit-testing y el controller, el helper numérico de `LevelId`, y la política de dificultad `LevelBlueprint`. Todo Dart puro, sin Flutter. Independiente de la Fase 1.

### Task 2.1: `ArrowBoard.arrowAt(Position)` y `arrowById(ArrowId)`

**Files:**
- Modify: `lib/domain/arrows/entities/arrow_board.dart`
- Test: `test/domain/arrow_board_test.dart`

**Interfaces:**
- Consumes: `Arrow` (tiene `cells: List<Position>`, `id: ArrowId`), `Position`, `ArrowId`.
- Produces:
  - `Arrow? arrowById(ArrowId id)` — la flecha con ese id, o `null`.
  - `Arrow? arrowAt(Position pos)` — la flecha que ocupa esa celda, o `null` si está vacía.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/domain/arrow_board_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

ArrowBoard _board() => ArrowBoard(
      cols: 4,
      rows: 4,
      arrows: [
        // ocupa (0,0) y (0,1)
        Arrow(
          id: const ArrowId('arrow-0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: ArrowLength(2),
        ),
        // ocupa (2,2) y (3,2)
        Arrow(
          id: const ArrowId('arrow-1'),
          tail: Position(row: 2, col: 2),
          direction: Direction.down,
          length: ArrowLength(2),
        ),
      ],
    );

void main() {
  group('ArrowBoard.arrowById', () {
    test('devuelve la flecha presente', () {
      expect(_board().arrowById(const ArrowId('arrow-1'))?.id,
          const ArrowId('arrow-1'));
    });
    test('devuelve null si el id no existe', () {
      expect(_board().arrowById(const ArrowId('nope')), isNull);
    });
  });

  group('ArrowBoard.arrowAt', () {
    test('devuelve la flecha que ocupa la celda', () {
      final a = _board().arrowAt(Position(row: 0, col: 1));
      expect(a?.id, const ArrowId('arrow-0'));
      final b = _board().arrowAt(Position(row: 3, col: 2));
      expect(b?.id, const ArrowId('arrow-1'));
    });
    test('devuelve null en una celda vacía', () {
      expect(_board().arrowAt(Position(row: 1, col: 1)), isNull);
    });
  });
}
```

> Nota: `ArrowLength(int)` y `Position({row, col})` NO son `const` (validan en el cuerpo); `ArrowId(String)` y `Arrow({...})` SÍ aceptan `const`. Por eso `ArrowLength(2)` va sin `const`.

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/domain/arrow_board_test.dart`
Expected: FAIL — `arrowById`/`arrowAt` no existen.

- [ ] **Step 3: Añadir las queries a `arrow_board.dart`**

Dentro de la clase `ArrowBoard`, tras el método `contains(...)`, añade:

```dart
  /// La flecha con [id], o null. Expone la búsqueda interna como query pública
  /// sin que los consumidores iteren `arrows` fuera del aggregate root.
  Arrow? arrowById(ArrowId id) => _findById(id);

  /// La flecha que ocupa la celda [pos], o null si está vacía. Es la base del
  /// hit-testing por celda (agnóstico de la forma de la flecha).
  Arrow? arrowAt(Position pos) {
    for (final a in arrows) {
      if (a.cells.contains(pos)) return a;
    }
    return null;
  }
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/domain/arrow_board_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/arrows/entities/arrow_board.dart test/domain/arrow_board_test.dart
git commit -m "feat(front/domain): add arrowAt and arrowById queries to ArrowBoard"
```

---

### Task 2.2: `LevelId.number`

**Files:**
- Modify: `lib/domain/board/value_objects/level_id.dart`
- Test: `test/domain/level_id_test.dart`

**Interfaces:**
- Produces: `int get number` en `LevelId` — `int.tryParse(value) ?? 1`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/domain/level_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';

void main() {
  test('number parsea el valor numérico', () {
    expect(LevelId('3').number, 3);
    expect(LevelId('12').number, 12);
  });
  test('number usa fallback 1 si no es numérico', () {
    expect(LevelId('abc').number, 1);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/domain/level_id_test.dart`
Expected: FAIL — `number` no existe.

- [ ] **Step 3: Añadir el getter a `level_id.dart`**

Dentro de la clase `LevelId`, antes de `props`, añade:

```dart
  /// Número de nivel para escalar dificultad y sembrar la generación.
  /// Fallback a 1 si el valor no es numérico (ids siempre son "1", "2", …).
  int get number => int.tryParse(value) ?? 1;
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/domain/level_id_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/board/value_objects/level_id.dart test/domain/level_id_test.dart
git commit -m "feat(front/domain): add LevelId.number for difficulty and seeding"
```

---

### Task 2.3: `LevelBlueprint` (curva de dificultad)

**Files:**
- Create: `lib/domain/board/value_objects/level_blueprint.dart`
- Test: `test/domain/level_blueprint_test.dart`

**Interfaces:**
- Produces:
  - `class LevelBlueprint` con `final int cols, rows, arrowCount;` y `const LevelBlueprint({required cols, required rows, required arrowCount})`.
  - `factory LevelBlueprint.forLevel(int level)` — tablero cuadrado `size = (4 + (level-1) ~/ 2).clamp(4, 9)`, `arrowCount = ((size*size*0.5)/3).round().clamp(4, size*size)`, `cols == rows == size`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/domain/level_blueprint_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_blueprint.dart';

void main() {
  group('LevelBlueprint.forLevel', () {
    test('nivel 1 produce el tablero mínimo cuadrado', () {
      final bp = LevelBlueprint.forLevel(1);
      expect(bp.cols, 4);
      expect(bp.rows, 4);
      expect(bp.cols, bp.rows);
      expect(bp.arrowCount, greaterThanOrEqualTo(4));
    });

    test('el tamaño crece con el nivel y se topa en 9', () {
      expect(LevelBlueprint.forLevel(1).cols, 4);
      expect(LevelBlueprint.forLevel(7).cols, greaterThan(4));
      expect(LevelBlueprint.forLevel(100).cols, 9);
    });

    test('size y arrowCount son monótonos no decrecientes', () {
      var prevSize = 0;
      var prevArrows = 0;
      for (var lvl = 1; lvl <= 30; lvl++) {
        final bp = LevelBlueprint.forLevel(lvl);
        expect(bp.cols, greaterThanOrEqualTo(prevSize));
        expect(bp.arrowCount, greaterThanOrEqualTo(prevArrows));
        prevSize = bp.cols;
        prevArrows = bp.arrowCount;
      }
    });

    test('niveles fuera de rango no rompen (clamp)', () {
      expect(LevelBlueprint.forLevel(0).cols, 4);
      expect(LevelBlueprint.forLevel(-5).cols, 4);
    });
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/domain/level_blueprint_test.dart`
Expected: FAIL — `LevelBlueprint` no existe.

- [ ] **Step 3: Crear `level_blueprint.dart`**

```dart
/// Política de dificultad (dominio puro): mapea un número de nivel a las
/// dimensiones del tablero y la cantidad de flechas. Concentra TODA la curva en
/// un solo lugar testeable; el generador solo genera, no decide dificultad.
class LevelBlueprint {
  final int cols;
  final int rows;
  final int arrowCount;

  const LevelBlueprint({
    required this.cols,
    required this.rows,
    required this.arrowCount,
  });

  /// Curva inicial: tablero cuadrado que crece de 4 a 9 con el nivel, relleno
  /// ~50 % con flechas de largo medio ~3. Ajustable sin tocar generador ni UI.
  factory LevelBlueprint.forLevel(int level) {
    final lvl = level < 1 ? 1 : level;
    final size = (4 + (lvl - 1) ~/ 2).clamp(4, 9);
    final arrowCount = ((size * size * 0.5) / 3).round().clamp(4, size * size);
    return LevelBlueprint(cols: size, rows: size, arrowCount: arrowCount);
  }
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/domain/level_blueprint_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/board/value_objects/level_blueprint.dart test/domain/level_blueprint_test.dart
git commit -m "feat(front/domain): add LevelBlueprint difficulty curve"
```

---

> **Fin de Fase 2.** Verificación: `flutter test test/domain/` en verde.

---

## Fase 3 — Generación escalada por nivel

Objetivo: el generador acepta `seed` (determinista por nivel), produce flechas de longitud ≥ 2, escala `maxAttempts` con el tamaño y mantiene el invariante de solubilidad (DAG). Depende de Fase 2 solo conceptualmente (la curva la aplica el controller en Fase 4).

> **Desviación consciente vs spec §8.3:** el logging AOP de "degradación" NO se implementa aquí — el generador no tiene `ILoggerService` inyectado hoy y añadirlo excede esta tarea. La degradación (colocar las flechas que se puedan) es inherente y segura; el log se puede añadir cuando se inyecte un logger.

### Task 3.1: Generador determinista + robusto (puerto + impl)

**Files:**
- Modify: `lib/domain/arrows/services/i_level_generator.dart`
- Modify: `lib/infrastructure/generators/graph_board_generator.dart`
- Test: `test/infrastructure/graph_board_generator_test.dart`

**Interfaces:**
- Produces:
  - Puerto: `ArrowBoard generate({required int cols, required int rows, required int arrowCount, int? seed})`.
  - Impl `GraphBoardGenerator()` (constructor sin args): determinista por `seed`; flechas de longitud `2..min(4, eje~/2)`; `maxAttempts = cols*rows*30`; ids `arrow-0..arrow-(n-1)`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/infrastructure/graph_board_generator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/infrastructure/generators/graph_board_generator.dart';

/// Solver voraz: retira repetidamente cualquier flecha con salida libre.
/// Si el tablero queda vacío, era solucionable (invariante DAG del generador).
bool _isSolvable(ArrowBoard board) {
  var b = board;
  var progress = true;
  while (!b.isCleared && progress) {
    progress = false;
    for (final a in List<Arrow>.from(b.arrows)) {
      if (b.canExit(a.id)) {
        b = b.removeArrow(a.id);
        progress = true;
        break;
      }
    }
  }
  return b.isCleared;
}

void main() {
  final gen = GraphBoardGenerator();

  test('es determinista: mismo seed produce el tablero idéntico', () {
    final a = gen.generate(cols: 6, rows: 6, arrowCount: 6, seed: 42);
    final b = gen.generate(cols: 6, rows: 6, arrowCount: 6, seed: 42);
    expect(a, b); // ArrowBoard es Equatable
  });

  test('respeta las dimensiones y nunca excede arrowCount', () {
    final board = gen.generate(cols: 7, rows: 7, arrowCount: 9, seed: 1);
    expect(board.cols, 7);
    expect(board.rows, 7);
    expect(board.arrows.length, lessThanOrEqualTo(9));
    expect(board.arrows, isNotEmpty);
  });

  test('todas las flechas tienen longitud >= 2', () {
    final board = gen.generate(cols: 8, rows: 8, arrowCount: 12, seed: 7);
    for (final a in board.arrows) {
      expect(a.length.value, greaterThanOrEqualTo(2));
    }
  });

  test('el tablero generado es siempre solucionable', () {
    for (final seed in [1, 2, 3, 99]) {
      final board = gen.generate(cols: 9, rows: 9, arrowCount: 14, seed: seed);
      expect(_isSolvable(board), isTrue, reason: 'seed=$seed');
    }
  });

  test('tableros grandes colocan más flechas que los pequeños', () {
    final small = gen.generate(cols: 4, rows: 4, arrowCount: 4, seed: 5);
    final big = gen.generate(cols: 9, rows: 9, arrowCount: 14, seed: 5);
    expect(big.arrows.length, greaterThan(small.arrows.length));
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/infrastructure/graph_board_generator_test.dart`
Expected: FAIL — la firma `generate` no acepta `seed` y/o longitudes incluyen 1.

- [ ] **Step 3: Actualizar el puerto**

Reemplazar `i_level_generator.dart` por:

```dart
import '../entities/arrow_board.dart';

abstract interface class ILevelGenerator {
  /// Genera un tablero solucionable (construcción DAG). [seed] hace la
  /// generación determinista (mismo seed ⇒ mismo tablero); null = aleatorio.
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    int? seed,
  });
}
```

- [ ] **Step 4: Reescribir la impl `graph_board_generator.dart`**

```dart
import 'dart:math';
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/arrows/value_objects/arrow_length.dart';
import '../../domain/game_core/value_objects/direction.dart';
import '../../domain/game_core/value_objects/position.dart';

// DAG: cada flecha se coloca solo si YA puede salir en el momento de colocarla.
// Esto garantiza solubilidad por construcción. La generación es determinista
// cuando se pasa [seed] (mismo seed ⇒ mismo tablero ⇒ restart reproducible).
class GraphBoardGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    int? seed,
  }) {
    final rng = Random(seed);
    final placed = <Arrow>[];
    final maxAttempts = cols * rows * 30; // escala con el tamaño del tablero
    var attempts = 0;

    while (placed.length < arrowCount && attempts < maxAttempts) {
      attempts++;
      final candidate = _randomArrow(rng, cols, rows, placed.length);
      if (candidate == null) continue;

      final tempBoard =
          ArrowBoard(arrows: [...placed, candidate], cols: cols, rows: rows);
      if (tempBoard.canExit(candidate.id)) {
        placed.add(candidate); // ids contiguos: arrow-0..arrow-(n-1)
      }
    }
    // Degradación con gracia: si no cupieron todas, devuelve las colocadas.
    return ArrowBoard(arrows: placed, cols: cols, rows: rows);
  }

  Arrow? _randomArrow(Random rng, int cols, int rows, int index) {
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final horizontal = dir == Direction.left || dir == Direction.right;
    final axis = horizontal ? cols : rows;
    final maxLen = min(4, axis ~/ 2);
    if (maxLen < 2) return null; // eje demasiado corto para una flecha de >=2
    final length = 2 + rng.nextInt(maxLen - 1); // 2..maxLen

    final (rowMin, rowMax, colMin, colMax) = switch (dir) {
      Direction.right => (0, rows - 1, 0, cols - length),
      Direction.left => (0, rows - 1, length - 1, cols - 1),
      Direction.down => (0, rows - length, 0, cols - 1),
      Direction.up => (length - 1, rows - 1, 0, cols - 1),
    };
    if (rowMax < rowMin || colMax < colMin) return null;
    final row = rowMin + rng.nextInt(rowMax - rowMin + 1);
    final col = colMin + rng.nextInt(colMax - colMin + 1);

    return Arrow(
      id: ArrowId('arrow-$index'),
      tail: Position(row: row, col: col),
      direction: dir,
      length: ArrowLength(length),
    );
  }
}
```

- [ ] **Step 5: Ejecutar el test para verlo pasar**

Run: `flutter test test/infrastructure/graph_board_generator_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/arrows/services/i_level_generator.dart lib/infrastructure/generators/graph_board_generator.dart test/infrastructure/graph_board_generator_test.dart
git commit -m "feat(front): deterministic, level-scalable board generation"
```

---

> **Fin de Fase 3.** Verificación: `flutter test test/infrastructure/graph_board_generator_test.dart` en verde. (`game_controller.dart` aún llama a `generate` sin `seed`; sigue compilando porque `seed` es opcional — se actualiza en Fase 4.)

---

## Fase 4 — Estado de aplicación (controller + feedback)

Objetivo: `CommandInvoker.clear()`, extender `GamePlaying` con señales transitorias y reescribir `GameController` para escalar por nivel (blueprint + seed), dar feedback de bloqueo/salida y soportar restart. Depende de Fases 2-3.

> **Bug latente corregido aquí:** el `undoMove` actual reconstruye, en el caso `GameWon`, un tablero vacío `ArrowBoard(arrows: [], cols: 4, rows: 4)` hardcodeado. Con tableros NxN eso reinsertaría la flecha en dimensiones equivocadas. Se reconstruye con las dimensiones del `LevelBlueprint` del nivel actual.

### Task 4.1: `CommandInvoker.clear()`

**Files:**
- Modify: `lib/application/commands/command_invoker.dart`
- Test: `test/application/command_invoker_test.dart`

**Interfaces:**
- Consumes: `ICommand` (existe), `ArrowBoard`.
- Produces: `void clear()` que vacía el historial (`canUndo == false` tras llamarlo).

- [ ] **Step 1: Escribir el test que falla**

Crear `test/application/command_invoker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/application/commands/command.dart';
import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';

class _NoopCommand implements ICommand {
  @override
  ArrowBoard execute(ArrowBoard board) => board;
  @override
  ArrowBoard undo(ArrowBoard board) => board;
}

void main() {
  final emptyBoard = const ArrowBoard(arrows: [], cols: 4, rows: 4);

  test('clear vacía el historial: canUndo pasa a false', () {
    final invoker = CommandInvoker();
    invoker.executeCommand(_NoopCommand(), emptyBoard);
    expect(invoker.canUndo, isTrue);

    invoker.clear();

    expect(invoker.canUndo, isFalse);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/application/command_invoker_test.dart`
Expected: FAIL — `clear` no existe.

- [ ] **Step 3: Añadir `clear()` a `command_invoker.dart`**

Dentro de la clase `CommandInvoker`, tras el método `undo(...)`, añade:

```dart
  /// Vacía el historial (para reiniciar un nivel sin arrastrar undos previos).
  void clear() => _history.clear();
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/application/command_invoker_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/application/commands/command_invoker.dart test/application/command_invoker_test.dart
git commit -m "feat(front/application): add CommandInvoker.clear for level restart"
```

---

### Task 4.2: `GamePlaying` extendido + `GameController` (blueprint, feedback, restart)

`game_state.dart` y `game_controller.dart` se cambian juntos: la nueva forma de `GamePlaying` no compila sin el controller que la produce, y viceversa. Un solo Task, un solo ciclo de test.

**Files:**
- Modify: `lib/application/state/game_state.dart`
- Modify: `lib/application/state/game_controller.dart`
- Test: `test/application/game_controller_test.dart` (+ `test/application/game_controller_test.mocks.dart` generado)

**Interfaces:**
- Consumes: `LevelBlueprint.forLevel` (2.3), `LevelId.number` (2.2), `ArrowBoard.arrowById` (2.1), `ILevelGenerator.generate({…, seed})` (3.1), `CommandInvoker.clear` (4.1), `RemoveArrowUseCase.execute → Either<DomainException, ArrowBoard>`, `RemoveArrowCommand`, `MoveCount`.
- Produces:
  - `GamePlaying({required ArrowBoard board, required MoveCount moves, ArrowId? blockedArrow, int blockedNonce = 0, Arrow? exitingArrow, int exitNonce = 0, bool canUndo = false})`.
  - `GameController.loadLevel(LevelId)`, `tapArrow(ArrowId)`, `undoMove()`, `restartLevel()`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/application/game_controller_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_blueprint.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'game_controller_test.mocks.dart';

@GenerateMocks([ILevelGenerator, RemoveArrowUseCase])
Arrow _arrow(String id, int col) => Arrow(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: ArrowLength(2),
    );

/// Tablero 4x4 con dos flechas (no se vacía al quitar una).
ArrowBoard _twoArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0), _arrow('arrow-2', 2)], cols: 4, rows: 4);

/// Tablero 4x4 con una sola flecha (al quitarla queda limpio → victoria).
ArrowBoard _oneArrowBoard() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0)], cols: 4, rows: 4);

ProviderContainer _container(MockILevelGenerator gen, MockRemoveArrowUseCase uc) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(gen, uc, CommandInvoker())),
  ]);
  addTearDown(c.dispose);
  return c;
}

void _stubGenerate(MockILevelGenerator gen, ArrowBoard board) {
  when(gen.generate(
    cols: anyNamed('cols'),
    rows: anyNamed('rows'),
    arrowCount: anyNamed('arrowCount'),
    seed: anyNamed('seed'),
  )).thenReturn(board);
}

void main() {
  test('loadLevel emite GamePlaying con el board generado y 0 movimientos', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    final board = _twoArrowBoard();
    _stubGenerate(gen, board);
    final c = _container(gen, uc);

    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GamePlaying>());
    expect((state as GamePlaying).moves.value, 0);
    expect(state.board, board);
    expect(state.canUndo, isFalse);
  });

  test('loadLevel usa las dimensiones del LevelBlueprint y seed = nivel', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    final c = _container(gen, uc);

    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('3'));

    final bp = LevelBlueprint.forLevel(3);
    verify(gen.generate(
            cols: bp.cols, rows: bp.rows, arrowCount: bp.arrowCount, seed: 3))
        .called(1);
  });

  test('tapArrow bloqueada hace shake: blockedArrow seteada y blockedNonce sube', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('blocked')));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));
    final s1 = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s1.blockedArrow, const ArrowId('arrow-0'));
    expect(s1.blockedNonce, 1);
    expect(s1.board.arrows.length, 2); // no cambió el tablero

    await notifier.tapArrow(const ArrowId('arrow-0'));
    final s2 = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s2.blockedNonce, 2); // re-dispara
  });

  test('tapArrow legal remueve la flecha, +1 movimiento, exitingArrow y canUndo', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.board.arrowById(const ArrowId('arrow-0')), isNull); // removida
    expect(s.board.arrows.length, 1);
    expect(s.moves.value, 1);
    expect(s.exitingArrow?.id, const ArrowId('arrow-0'));
    expect(s.exitNonce, 1);
    expect(s.canUndo, isTrue);
  });

  test('tapArrow que limpia el tablero emite GameWon', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _oneArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    await notifier.tapArrow(const ArrowId('arrow-0'));

    final state = c.read(gameControllerProvider).valueOrNull;
    expect(state, isA<GameWon>());
    expect((state as GameWon).moves.value, 1);
  });

  test('undoMove restaura el tablero y decrementa movimientos', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    await notifier.tapArrow(const ArrowId('arrow-0'));

    await notifier.undoMove();

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.board.arrows.length, 2); // flecha reinsertada
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
  });

  test('restartLevel limpia el historial y regenera (canUndo false, 0 movimientos)', () async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    _stubGenerate(gen, _twoArrowBoard());
    when(uc.execute(any, any)).thenReturn(Right(_twoArrowBoard()));
    final c = _container(gen, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('2'));
    await notifier.tapArrow(const ArrowId('arrow-0'));

    await notifier.restartLevel();

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
    expect(s.board.arrows.length, 2);
  });
}
```

- [ ] **Step 2: Generar los mocks y ejecutar el test para verlo fallar**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/application/game_controller_test.dart
```
Expected: FAIL — `GamePlaying` no tiene los campos nuevos / `restartLevel` no existe.

- [ ] **Step 3: Reescribir `game_state.dart`**

```dart
import '../../domain/arrows/entities/arrow.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';

// State Pattern (sealed): estados mutuamente excluyentes del juego.
sealed class GameState {}

class GameLoading extends GameState {}

class GamePlaying extends GameState {
  final ArrowBoard board;
  final MoveCount moves;

  // Señales TRANSITORIAS de presentación (no son reglas de dominio):
  final ArrowId? blockedArrow; // última flecha tocada que no puede salir
  final int blockedNonce; // ++ por bloqueo → re-dispara el shake
  final Arrow? exitingArrow; // "fantasma" de la flecha recién removida
  final int exitNonce; // ++ por salida → re-dispara el slide-out
  final bool canUndo; // habilita el botón undo del top bar

  GamePlaying({
    required this.board,
    required this.moves,
    this.blockedArrow,
    this.blockedNonce = 0,
    this.exitingArrow,
    this.exitNonce = 0,
    this.canUndo = false,
  });
}

class GameWon extends GameState {
  final MoveCount moves;
  GameWon({required this.moves});
}
```

- [ ] **Step 4: Reescribir `game_controller.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/value_objects/level_blueprint.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../../domain/game_core/value_objects/move_count.dart';
import '../commands/command_invoker.dart';
import '../commands/remove_arrow_command.dart';
import '../use_cases/remove_arrow_use_case.dart';
import 'game_state.dart';

// El provider se compone en core/ (DI) o se sobreescribe en tests; la fábrica
// por defecto falla explícitamente para no acoplar este archivo a impls
// concretas (DIP) antes de que existan.
final gameControllerProvider =
    AsyncNotifierProvider<GameController, GameState>(
  () => throw UnimplementedError(
    'gameControllerProvider must be overridden with composed dependencies',
  ),
);

/// Fachada reactiva (Riverpod) entre la UI y los casos de uso de dominio.
class GameController extends AsyncNotifier<GameState> {
  final ILevelGenerator _generator;
  final RemoveArrowUseCase _removeArrow;
  final CommandInvoker _invoker;

  GameController(this._generator, this._removeArrow, this._invoker);

  // Estado con alcance de partida (no de dominio).
  LevelId? _currentLevel;
  int _blockedNonce = 0;
  int _exitNonce = 0;

  @override
  Future<GameState> build() async => GameLoading();

  Future<void> loadLevel(LevelId levelId) async {
    // Aseguramos que build() haya resuelto antes de mutar el estado.
    await future;
    _currentLevel = levelId;
    _blockedNonce = 0;
    _exitNonce = 0;
    _invoker.clear();

    // La dificultad la decide LevelBlueprint (dominio); el generador solo genera.
    final bp = LevelBlueprint.forLevel(levelId.number);
    final board = _generator.generate(
      cols: bp.cols,
      rows: bp.rows,
      arrowCount: bp.arrowCount,
      seed: levelId.number, // determinista: mismo nivel ⇒ mismo tablero
    );
    state = AsyncValue.data(
      GamePlaying(board: board, moves: const MoveCount(0), canUndo: false),
    );
  }

  Future<void> tapArrow(ArrowId arrowId) async {
    final current = state.valueOrNull;
    if (current is! GamePlaying) return;

    final result = _removeArrow.execute(current.board, arrowId);
    result.fold(
      (_) {
        // Bloqueada o ausente → feedback de shake (sin cambiar el tablero).
        _blockedNonce++;
        state = AsyncValue.data(GamePlaying(
          board: current.board,
          moves: current.moves,
          blockedArrow: arrowId,
          blockedNonce: _blockedNonce,
          exitNonce: _exitNonce,
          canUndo: _invoker.canUndo,
        ));
      },
      (_) {
        // Legal: captura la flecha (para el fantasma de salida) y la remueve
        // por Command para mantener el historial de undo coherente.
        final removed = current.board.arrowById(arrowId);
        final cmd = RemoveArrowCommand(arrowId);
        final newBoard = _invoker.executeCommand(cmd, current.board);
        final newMoves = current.moves.increment();
        _exitNonce++;
        if (newBoard.isCleared) {
          state = AsyncValue.data(GameWon(moves: newMoves));
        } else {
          state = AsyncValue.data(GamePlaying(
            board: newBoard,
            moves: newMoves,
            exitingArrow: removed,
            exitNonce: _exitNonce,
            blockedNonce: _blockedNonce,
            canUndo: _invoker.canUndo,
          ));
        }
      },
    );
  }

  Future<void> undoMove() async {
    if (!_invoker.canUndo) return;
    final current = state.valueOrNull;

    final ArrowBoard currentBoard;
    final int currentMoves;
    if (current is GamePlaying) {
      currentBoard = current.board;
      currentMoves = current.moves.value;
    } else if (current is GameWon) {
      // Tras la victoria el tablero quedó vacío; reconstruimos uno vacío con
      // las dimensiones REALES del nivel (no 4x4 fijo) para reinsertar bien.
      final bp = LevelBlueprint.forLevel((_currentLevel ?? LevelId('1')).number);
      currentBoard = ArrowBoard(arrows: const [], cols: bp.cols, rows: bp.rows);
      currentMoves = current.moves.value;
    } else {
      return;
    }

    final previousBoard = _invoker.undo(currentBoard);
    final previousMoves = MoveCount(currentMoves > 0 ? currentMoves - 1 : 0);
    state = AsyncValue.data(GamePlaying(
      board: previousBoard,
      moves: previousMoves,
      blockedNonce: _blockedNonce,
      exitNonce: _exitNonce,
      canUndo: _invoker.canUndo,
    ));
  }

  Future<void> restartLevel() async {
    final level = _currentLevel;
    if (level != null) {
      await loadLevel(level); // determinista ⇒ mismo tablero
    }
  }
}
```

- [ ] **Step 5: Ejecutar el test para verlo pasar**

Run: `flutter test test/application/game_controller_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/application/state/game_state.dart lib/application/state/game_controller.dart test/application/game_controller_test.dart test/application/game_controller_test.mocks.dart
git commit -m "feat(front/application): level-scaled loadLevel, blocked/exit feedback, restart"
```

---

> **Fin de Fase 4.** Verificación: `flutter test test/application/ test/domain/ test/infrastructure/` en verde. La lógica de juego (sin UI) queda completa y testeada.

---

## Fase 5 — Render del tablero (arregla los 2 bugs visuales)

Objetivo: painter por polilínea (cuerpo grueso + glow + punta), `ArrowWidget` render-puro con shake, `ExitingArrowWidget` auto-desmontable, y `BoardWidget` responsive con **hit-testing por celda**. Depende de Fases 1 (color), 2 (`arrowAt`) y 4 (estado).

> Al terminar Fase 5, `flutter analyze` debe quedar limpio: aquí desaparecen las últimas referencias a `arrowUp/Down/Left/Right` y a la firma vieja del painter.

### Task 5.1: `ArrowPainter` por polilínea

**Files:**
- Modify: `lib/presentation/game/painters/arrow_painter.dart` (reescritura completa)
- Test: `test/presentation/arrow_painter_test.dart`

**Interfaces:**
- Consumes: `Position` (`.row`, `.col`).
- Produces: `ArrowPainter({required List<Position> cells, required int minCol, required int minRow, required double cell, required Color color})`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/arrow_painter_test.dart`:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/game/painters/arrow_painter.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

ArrowPainter _painter(Color color) => ArrowPainter(
      cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
      minCol: 0,
      minRow: 0,
      cell: 40,
      color: color,
    );

void main() {
  test('pinta una flecha recta sin lanzar', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    expect(() => _painter(const Color(0xFF46B98C)).paint(canvas, const Size(80, 40)),
        returnsNormally);
  });

  test('shouldRepaint es true al cambiar el color', () {
    final a = _painter(const Color(0xFF46B98C));
    final b = _painter(const Color(0xFFD56C8E));
    expect(b.shouldRepaint(a), isTrue);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/arrow_painter_test.dart`
Expected: FAIL — la firma `ArrowPainter` aún es la vieja (`arrow`/`cellSize`/`isHighlighted`).

- [ ] **Step 3: Reescribir `arrow_painter.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/game_core/value_objects/position.dart';

/// Pinta una flecha multi-celda como una POLILÍNEA gruesa (recorre los centros
/// de `cells`) con glow, brillo interior y punta triangular orientada por el
/// último segmento. Coordenadas locales al bounding box (origen minCol/minRow).
///
/// Agnóstico de la forma: sirve igual para flechas rectas y, en el futuro,
/// dobladas — solo depende de `cells` y de la orientación de la punta.
class ArrowPainter extends CustomPainter {
  final List<Position> cells;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;

  const ArrowPainter({
    required this.cells,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
  });

  Offset _center(Position p) => Offset(
        (p.col - minCol + 0.5) * cell,
        (p.row - minRow + 0.5) * cell,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final stroke = cell * 0.40;

    final body = Path();
    final first = _center(cells.first);
    body.moveTo(first.dx, first.dy);
    for (final p in cells.skip(1)) {
      final c = _center(p);
      body.lineTo(c.dx, c.dy);
    }

    // Glow (debajo).
    canvas.drawPath(
      body,
      Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.45),
    );

    // Cuerpo.
    canvas.drawPath(
      body,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Brillo interior.
    canvas.drawPath(
      body,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    _drawHead(canvas, stroke);
  }

  void _drawHead(Canvas canvas, double stroke) {
    final tip = _center(cells.last);
    final prev = cells.length >= 2
        ? _center(cells[cells.length - 2])
        : Offset(tip.dx - cell, tip.dy);
    final angle = math.atan2(tip.dy - prev.dy, tip.dx - prev.dx);
    final headLen = stroke * 1.2;
    final headHalf = stroke * 0.95;

    // Vértice adelantado medio celda para que sobresalga como punta.
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

  @override
  bool shouldRepaint(covariant ArrowPainter old) =>
      old.cells != cells || old.color != color || old.cell != cell;
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/arrow_painter_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/game/painters/arrow_painter.dart test/presentation/arrow_painter_test.dart
git commit -m "refactor(front/presentation): rewrite ArrowPainter as a thick cell polyline"
```

---

### Task 5.2: `ArrowWidget` (render + shake) y `ExitingArrowWidget` (slide-out)

Ambos son envoltorios finos sobre `ArrowPainter` (render puro + animación), cambian juntos visualmente. Un Task.

**Files:**
- Modify: `lib/presentation/game/widgets/arrow_widget.dart` (reescritura)
- Modify: `lib/presentation/game/widgets/exiting_arrow_widget.dart` (reescritura)
- Test: `test/presentation/arrow_widget_test.dart` (smoke de render)

**Interfaces:**
- Consumes: `Arrow` (`.cells`, `.direction`), `Direction`, `ArrowPainter` (5.1).
- Produces:
  - `ArrowWidget({Key? key, required Arrow arrow, required int minCol, required int minRow, required double cell, required Color color, required bool isBlocked, required int blockedNonce})`.
  - `ExitingArrowWidget({Key? key, required Arrow arrow, required int minCol, required int minRow, required double cell, required Color color, required double travel, required int nonce})`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/arrow_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

void main() {
  testWidgets('ArrowWidget renderiza sin error', (tester) async {
    final arrow = Arrow(
      id: const ArrowId('arrow-0'),
      tail: Position(row: 0, col: 0),
      direction: Direction.right,
      length: ArrowLength(2),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 100,
          child: ArrowWidget(
            arrow: arrow,
            minCol: 0,
            minRow: 0,
            cell: 50,
            color: const Color(0xFF46B98C),
            isBlocked: false,
            blockedNonce: 0,
          ),
        ),
      ),
    ));
    expect(find.byType(ArrowWidget), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/arrow_widget_test.dart`
Expected: FAIL — la firma de `ArrowWidget` aún es la vieja.

- [ ] **Step 3: Reescribir `arrow_widget.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../painters/arrow_painter.dart';

/// Pieza visual del tablero: pinta la flecha y, si está bloqueada, hace un
/// "shake" hacia su dirección de salida. NO captura toques (el hit-testing por
/// celda vive en BoardWidget); por eso va envuelta en [IgnorePointer].
class ArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;
  final bool isBlocked;
  final int blockedNonce;

  const ArrowWidget({
    super.key,
    required this.arrow,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
    required this.isBlocked,
    required this.blockedNonce,
  });

  @override
  State<ArrowWidget> createState() => _ArrowWidgetState();
}

class _ArrowWidgetState extends State<ArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void didUpdateWidget(covariant ArrowWidget old) {
    super.didUpdateWidget(old);
    if (widget.isBlocked && widget.blockedNonce != old.blockedNonce) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  (double, double) _dirUnit() => switch (widget.arrow.direction) {
        Direction.up => (0, -1),
        Direction.down => (0, 1),
        Direction.left => (-1, 0),
        Direction.right => (1, 0),
      };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final magnitude = math.sin(t * math.pi * 4) * (1 - t) * 7;
          final (ux, uy) = _dirUnit();
          return Transform.translate(
            offset: Offset(ux * magnitude, uy * magnitude),
            child: child,
          );
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: ArrowPainter(
            cells: widget.arrow.cells,
            minCol: widget.minCol,
            minRow: widget.minRow,
            cell: widget.cell,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Reescribir `exiting_arrow_widget.dart`**

```dart
import 'package:flutter/material.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/direction.dart';
import '../painters/arrow_painter.dart';

/// Overlay cosmético de la flecha recién removida: se desliza fuera del tablero
/// en su dirección y se desvanece. Auto-desmontable: al terminar renderiza
/// vacío. Debe ir keyed por el `exitNonce` para que cada salida re-anime.
class ExitingArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final int minCol;
  final int minRow;
  final double cell;
  final Color color;
  final double travel;
  final int nonce;

  const ExitingArrowWidget({
    super.key,
    required this.arrow,
    required this.minCol,
    required this.minRow,
    required this.cell,
    required this.color,
    required this.travel,
    required this.nonce,
  });

  @override
  State<ExitingArrowWidget> createState() => _ExitingArrowWidgetState();
}

class _ExitingArrowWidgetState extends State<ExitingArrowWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Offset _dirUnit() => switch (widget.arrow.direction) {
        Direction.up => const Offset(0, -1),
        Direction.down => const Offset(0, 1),
        Direction.left => const Offset(-1, 0),
        Direction.right => const Offset(1, 0),
      };

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          if (_c.isCompleted) return const SizedBox.shrink();
          final t = Curves.easeIn.transform(_c.value);
          final d = _dirUnit();
          return Transform.translate(
            offset: Offset(d.dx * widget.travel * t, d.dy * widget.travel * t),
            child: Opacity(opacity: 1 - t, child: child),
          );
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: ArrowPainter(
            cells: widget.arrow.cells,
            minCol: widget.minCol,
            minRow: widget.minRow,
            cell: widget.cell,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/arrow_widget_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/game/widgets/arrow_widget.dart lib/presentation/game/widgets/exiting_arrow_widget.dart test/presentation/arrow_widget_test.dart
git commit -m "refactor(front/presentation): render-only ArrowWidget with shake + exit slide-out"
```

---

### Task 5.3: `BoardWidget` responsive + hit-testing por celda (regresión del bug)

**Files:**
- Modify: `lib/presentation/game/widgets/board_widget.dart` (reescritura)
- Test: `test/presentation/board_widget_hit_test.dart` (+ `.mocks.dart` generado)

**Interfaces:**
- Consumes: `gameControllerProvider` (estado `GamePlaying`), `ArrowBoard.arrowAt` (2.1), `arrowColorFor` (1.3), `ArrowWidget`/`ExitingArrowWidget` (5.2), `AppColors`.
- Produces: `BoardWidget` (`ConsumerWidget`, sin parámetros) que lee el estado, dibuja la rejilla, posiciona cada flecha en su bbox y enruta los toques por celda a `tapArrow`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/board_widget_hit_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import 'board_widget_hit_test.mocks.dart';

@GenerateMocks([ILevelGenerator, RemoveArrowUseCase])
Arrow _arrow(String id, int col) => Arrow(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: ArrowLength(2),
    );

// 4x4: arrow-0 ocupa (0,0)-(0,1); arrow-2 ocupa (0,2)-(0,3).
ArrowBoard _board() =>
    ArrowBoard(arrows: [_arrow('arrow-0', 0), _arrow('arrow-2', 2)], cols: 4, rows: 4);

Future<ProviderContainer> _ready(
    WidgetTester tester, MockILevelGenerator gen, MockRemoveArrowUseCase uc) async {
  when(gen.generate(
    cols: anyNamed('cols'),
    rows: anyNamed('rows'),
    arrowCount: anyNamed('arrowCount'),
    seed: anyNamed('seed'),
  )).thenReturn(_board());
  final container = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(gen, uc, CommandInvoker())),
  ]);
  addTearDown(container.dispose);
  await container.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 400, child: BoardWidget()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('un toque enruta a la flecha de ESA celda (fix del bug)',
      (tester) async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('x'))); // evita mutar el board
    await _ready(tester, gen, uc);

    // Celda (row 0, col 2) → centro ≈ (250, 50) con cell=100 en 400x400.
    await tester.tapAt(const Offset(250, 50));
    await tester.pump();

    // mockito: si un arg es matcher (`any`), TODOS deben serlo → argThat.
    verify(uc.execute(any, argThat(equals(const ArrowId('arrow-2'))))).called(1);
    verifyNever(uc.execute(any, argThat(equals(const ArrowId('arrow-0')))));
  });

  testWidgets('tocar una celda vacía no dispara nada', (tester) async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    when(uc.execute(any, any)).thenReturn(Left(InvalidMoveException('x')));
    await _ready(tester, gen, uc);

    // Celda (row 2, col 1) → (150, 250): no hay flecha allí.
    await tester.tapAt(const Offset(150, 250));
    await tester.pump();

    verifyNever(uc.execute(any, any));
  });
}
```

- [ ] **Step 2: Generar mocks y ejecutar el test para verlo fallar**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/presentation/board_widget_hit_test.dart
```
Expected: FAIL — `BoardWidget` aún apila flechas sin `Positioned` ni hit-testing por celda.

- [ ] **Step 3: Reescribir `board_widget.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../application/state/game_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/arrows/entities/arrow.dart';
import '../../../domain/game_core/value_objects/position.dart';
import '../../providers/game_provider.dart';
import '../arrow_color.dart';
import 'arrow_widget.dart';
import 'exiting_arrow_widget.dart';

/// Rejilla del tablero: panel de `cols x rows` celdas con una flecha por
/// `Positioned` (su bounding box). El hit-testing es POR CELDA mediante un único
/// GestureDetector (a prueba de forma: recta o doblada) — esto resuelve el bug
/// de "no se sabe qué flecha se toca". Consume el estado vía gameControllerProvider.
class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider).valueOrNull;
    if (state is! GamePlaying) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final gridColor = (isDark
            ? AppColors.onSurfaceMuted
            : AppColors.lightOnSurfaceMuted)
        .withValues(alpha: 0.10);

    final board = state.board;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = math.min(
          constraints.maxWidth / board.cols,
          constraints.maxHeight / board.rows,
        );
        final width = board.cols * cell;
        final height = board.rows * cell;

        return SizedBox(
          width: width,
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final col = (details.localPosition.dx / cell)
                  .floor()
                  .clamp(0, board.cols - 1);
              final row = (details.localPosition.dy / cell)
                  .floor()
                  .clamp(0, board.rows - 1);
              final arrow = board.arrowAt(Position(row: row, col: col));
              if (arrow != null) {
                ref.read(gameControllerProvider.notifier).tapArrow(arrow.id);
              }
            },
            child: Stack(
              clipBehavior: Clip.none, // la flecha saliente cruza el borde
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: surface.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(cell * 0.35),
                    ),
                    child: CustomPaint(
                      painter: _GridPainter(board.cols, board.rows, gridColor),
                    ),
                  ),
                ),
                for (final arrow in board.arrows) _positionArrow(arrow, cell, state),
                if (state.exitingArrow != null)
                  _positionExiting(
                    state.exitingArrow!,
                    cell,
                    state.exitNonce,
                    math.max(width, height),
                  ),
              ],
            ),
          ),
        );
      },
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

  Widget _positionArrow(Arrow arrow, double cell, GamePlaying state) {
    final b = _bounds(arrow);
    return Positioned(
      left: b.minCol * cell,
      top: b.minRow * cell,
      width: (b.maxCol - b.minCol + 1) * cell,
      height: (b.maxRow - b.minRow + 1) * cell,
      child: ArrowWidget(
        key: ValueKey(arrow.id.value),
        arrow: arrow,
        minCol: b.minCol,
        minRow: b.minRow,
        cell: cell,
        color: arrowColorFor(arrow.id),
        isBlocked: state.blockedArrow == arrow.id,
        blockedNonce: state.blockedNonce,
      ),
    );
  }

  Widget _positionExiting(Arrow arrow, double cell, int nonce, double travel) {
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
        cell: cell,
        color: arrowColorFor(arrow.id),
        travel: travel * 1.15,
        nonce: nonce,
      ),
    );
  }
}

/// Rejilla de fondo muy sutil.
class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final Color color;
  const _GridPainter(this.cols, this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cw = size.width / cols;
    final ch = size.height / rows;
    for (var i = 1; i < cols; i++) {
      canvas.drawLine(Offset(cw * i, 0), Offset(cw * i, size.height), paint);
    }
    for (var j = 1; j < rows; j++) {
      canvas.drawLine(Offset(0, ch * j), Offset(size.width, ch * j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols || old.rows != rows || old.color != color;
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/board_widget_hit_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Verificar el lint global**

Run: `flutter analyze`
Expected: sin errores (las referencias a `arrowUp/Down/Left/Right` y a la firma vieja del painter ya no existen). Si aparece algo en `game_screen.dart`/`exiting` por APIs viejas, se resuelve en Fase 6.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/game/widgets/board_widget.dart test/presentation/board_widget_hit_test.dart test/presentation/board_widget_hit_test.mocks.dart
git commit -m "feat(front/presentation): responsive board with per-cell hit-testing"
```

---

> **Fin de Fase 5.** Verificación: `flutter test` (toda la suite hasta aquí) en verde. El tablero ya se ve con cuerpos gruesos multicolor y responde al toque correcto. (Las pantallas/top bar se rehacen en Fase 6.)

---

## Fase 6 — Pantallas y navegación

Objetivo: home con logo animado, top bar custom (píldora de nivel + undo/restart), victoria rediseñada (recibe levelId+moves), selector re-tematizado, y la ruta de victoria con argumentos. Copy en español. Depende de Fases 4-5.

> **Bug latente corregido aquí:** `_fade` no propaga `settings`, así que la victoria actual siempre lee `arguments == null` (muestra "0 movimientos"). Se resuelve desempacando los argumentos en `onGenerateRoute` y pasándolos por constructor (como ya hace la ruta `game`).

### Task 6.1: Ruta de victoria con argumentos + `VictoryScreen` rediseñada

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/presentation/level_selection/victory_screen.dart` (reescritura)
- Test: `test/presentation/victory_screen_test.dart`

**Interfaces:**
- Produces:
  - `class VictoryArgs { final LevelId levelId; final int moves; const VictoryArgs({required this.levelId, required this.moves}); }` (en `app_router.dart`).
  - `VictoryScreen({Key? key, required LevelId levelId, required int moves})`.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/victory_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/victory_screen.dart';

void main() {
  testWidgets('muestra el nivel y los movimientos recibidos', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: VictoryScreen(levelId: LevelId('4'), moves: 7),
    ));
    await tester.pump(const Duration(milliseconds: 700)); // deja correr el trofeo

    expect(find.text('¡Tablero limpio!'), findsOneWidget);
    expect(find.textContaining('Nivel 4'), findsOneWidget);
    expect(find.textContaining('7 movimientos'), findsOneWidget);
    expect(find.text('Siguiente nivel'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/victory_screen_test.dart`
Expected: FAIL — `VictoryScreen` aún no recibe `levelId`/`moves` por constructor.

- [ ] **Step 3: Reescribir `victory_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';

/// Pantalla de victoria: confirma el tablero limpiado, muestra nivel y
/// movimientos, y ofrece siguiente nivel / reintentar / volver a niveles.
class VictoryScreen extends StatelessWidget {
  final LevelId levelId;
  final int moves;

  const VictoryScreen({super.key, required this.levelId, required this.moves});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final bgDeep =
        isDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep;
    final onBg = isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;

    final nextLevel = LevelId('${levelId.number + 1}');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: [bg, bgDeep],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    child: const Icon(Icons.emoji_events,
                        size: 96, color: AppColors.victory),
                  ),
                  const SizedBox(height: 16),
                  Text('¡Tablero limpio!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: onBg,
                            fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 8),
                  Text('Nivel ${levelId.value} · $moves movimientos',
                      style: TextStyle(color: muted)),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Siguiente nivel'),
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, AppRouter.game,
                        arguments: nextLevel),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Reintentar'),
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, AppRouter.game,
                        arguments: levelId),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, AppRouter.levelSelection, (_) => false),
                    child: const Text('Volver a niveles'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Actualizar `app_router.dart`** (añadir `VictoryArgs` y desempacar)

Reemplaza el contenido por:

```dart
import 'package:flutter/material.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../presentation/game/screens/game_screen.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/level_selection/level_selection_screen.dart';
import '../../presentation/level_selection/victory_screen.dart';

/// Argumentos de la ruta de victoria (nivel completado + movimientos usados).
class VictoryArgs {
  final LevelId levelId;
  final int moves;
  const VictoryArgs({required this.levelId, required this.moves});
}

/// Tabla de rutas nombradas. Centraliza la navegación y desacopla las pantallas.
class AppRouter {
  AppRouter._();

  static const String home = '/';
  static const String levelSelection = '/levels';
  static const String game = '/game';
  static const String victory = '/victory';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRouter.home => _fade(const HomeScreen()),
      AppRouter.levelSelection => _fade(const LevelSelectionScreen()),
      AppRouter.game => _fade(
          GameScreen(
            levelId: settings.arguments is LevelId
                ? settings.arguments as LevelId
                : LevelId('1'),
          ),
        ),
      AppRouter.victory => _fade(_victory(settings.arguments)),
      _ => _fade(const HomeScreen()),
    };
  }

  static Widget _victory(Object? args) => args is VictoryArgs
      ? VictoryScreen(levelId: args.levelId, moves: args.moves)
      : VictoryScreen(levelId: LevelId('1'), moves: 0);

  static MaterialPageRoute<dynamic> _fade(Widget page) =>
      MaterialPageRoute<dynamic>(builder: (_) => page);
}
```

- [ ] **Step 5: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/victory_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add lib/core/router/app_router.dart lib/presentation/level_selection/victory_screen.dart test/presentation/victory_screen_test.dart
git commit -m "feat(front/presentation): redesigned victory screen with level + moves args"
```

---

### Task 6.2: `HomeScreen` rediseñada + logo animado

**Files:**
- Modify: `lib/presentation/home/screens/home_screen.dart` (reescritura)
- Test: `test/presentation/home_screen_test.dart`

**Interfaces:**
- Consumes: `AppRouter.levelSelection`, `AppColors`.
- Produces: `HomeScreen` (StatelessWidget) con título, tagline y CTA "JUGAR".

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';

void main() {
  testWidgets('muestra título, tagline y CTA en español', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(); // un frame; el logo anima en bucle (no pumpAndSettle)

    expect(find.text('ARROW MAZE'), findsOneWidget);
    expect(find.text('Despeja el tablero. Saca cada flecha.'), findsOneWidget);
    expect(find.text('JUGAR'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/home_screen_test.dart`
Expected: FAIL — la home aún dice "Arrow Maze"/"Play".

- [ ] **Step 3: Reescribir `home_screen.dart`**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Pantalla inicial: logo animado de flechas, título y CTA "JUGAR".
/// Solo presentación; navega por nombre de ruta sin conocer la pantalla destino.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final bgDeep =
        isDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep;
    final onBg = isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    final muted =
        isDark ? AppColors.onSurfaceMuted : AppColors.lightOnSurfaceMuted;
    final seed = isDark ? AppColors.primary : AppColors.lightPrimary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.1,
            colors: [bg, bgDeep],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LogoArrows(),
                const SizedBox(height: 28),
                Text('ARROW MAZE',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: onBg,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        )),
                const SizedBox(height: 8),
                Text('Despeja el tablero. Saca cada flecha.',
                    style: TextStyle(color: muted, fontSize: 15)),
                const SizedBox(height: 48),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: seed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.levelSelection),
                  child: const Text('JUGAR',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Clúster decorativo de flechas con flotación perpetua sutil.
class _LogoArrows extends StatefulWidget {
  const _LogoArrows();

  @override
  State<_LogoArrows> createState() => _LogoArrowsState();
}

class _LogoArrowsState extends State<_LogoArrows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 140,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final base = _controller.value * 2 * math.pi;
          return Stack(
            alignment: Alignment.center,
            children: [
              _bar(36, 2, AppColors.arrowPalette[1], Icons.arrow_forward,
                  math.sin(base)),
              _bar(-36, 28, AppColors.arrowPalette[0], Icons.arrow_downward,
                  math.sin(base + 2.1)),
              _bar(2, -28, AppColors.arrowPalette[5], Icons.arrow_upward,
                  math.sin(base + 4.2)),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(double dx, double dy, Color color, IconData icon, double bob) {
    return Transform.translate(
      offset: Offset(dx, dy + bob * 5),
      child: Container(
        width: 66,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 18),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/home_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/home/screens/home_screen.dart test/presentation/home_screen_test.dart
git commit -m "feat(front/presentation): redesign home with animated arrow logo (ES copy)"
```

---

### Task 6.3: `GameScreen` con top bar custom + AnimatedSwitcher + restart

**Files:**
- Modify: `lib/presentation/game/screens/game_screen.dart` (reescritura)
- Test: `test/presentation/game_screen_test.dart` (+ `.mocks.dart` generado)

**Interfaces:**
- Consumes: `gameControllerProvider` (`loadLevel`, `undoMove`, `restartLevel`, estado), `BoardWidget`, `AppRouter.victory`+`VictoryArgs`, `AppColors`.
- Produces: `GameScreen({Key? key, required LevelId levelId})` (ConsumerStatefulWidget).

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/game_screen_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/presentation/game/screens/game_screen.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';

import 'game_screen_test.mocks.dart';

@GenerateMocks([ILevelGenerator, RemoveArrowUseCase])
ArrowBoard _board() => ArrowBoard(
      arrows: [
        Arrow(
          id: const ArrowId('arrow-0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: ArrowLength(2),
        ),
      ],
      cols: 4,
      rows: 4,
    );

void main() {
  testWidgets('muestra la píldora del nivel y el tablero', (tester) async {
    final gen = MockILevelGenerator();
    final uc = MockRemoveArrowUseCase();
    when(gen.generate(
      cols: anyNamed('cols'),
      rows: anyNamed('rows'),
      arrowCount: anyNamed('arrowCount'),
      seed: anyNamed('seed'),
    )).thenReturn(_board());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameControllerProvider
            .overrideWith(() => GameController(gen, uc, CommandInvoker())),
      ],
      child: MaterialApp(home: GameScreen(levelId: LevelId('5'))),
    ));
    // post-frame loadLevel + microtask + AnimatedSwitcher.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('5'), findsOneWidget); // píldora de nivel
    expect(find.byType(BoardWidget), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}
```

- [ ] **Step 2: Generar mocks y ejecutar el test para verlo fallar**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/presentation/game_screen_test.dart
```
Expected: FAIL — la pantalla aún usa AppBar con "Moves: …" y no hay píldora.

- [ ] **Step 3: Reescribir `game_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/state/game_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/board/value_objects/level_id.dart';
import '../../providers/game_provider.dart';
import '../widgets/board_widget.dart';

// Re-exporta el provider para que el router (core) referencie GameScreen sin
// alcanzar application/state directamente.
export '../../providers/game_provider.dart' show gameControllerProvider;

/// Pantalla de partida: top bar custom (atrás, píldora de nivel, undo, restart)
/// + tablero. Dispara loadLevel tras el primer frame y navega a victoria al ganar.
class GameScreen extends ConsumerStatefulWidget {
  final LevelId levelId;
  const GameScreen({super.key, required this.levelId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameControllerProvider.notifier).loadLevel(widget.levelId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final bgDeep =
        isDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep;

    ref.listen(gameControllerProvider, (_, next) {
      final s = next.valueOrNull;
      if (s is GameWon) {
        Navigator.pushReplacementNamed(
          context,
          AppRouter.victory,
          arguments: VictoryArgs(levelId: widget.levelId, moves: s.moves.value),
        );
      }
    });

    final asyncState = ref.watch(gameControllerProvider);
    final playing = asyncState.valueOrNull;
    final canUndo = playing is GamePlaying && playing.canUndo;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.2,
            colors: [bg, bgDeep],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                levelLabel: widget.levelId.value,
                canUndo: canUndo,
                onBack: () => Navigator.of(context).maybePop(),
                onUndo: () =>
                    ref.read(gameControllerProvider.notifier).undoMove(),
                onRestart: () =>
                    ref.read(gameControllerProvider.notifier).restartLevel(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.96, end: 1)
                              .animate(anim),
                          child: child,
                        ),
                      ),
                      child: asyncState.when(
                        data: (s) => s is GamePlaying
                            ? const BoardWidget(key: ValueKey('playing'))
                            : const SizedBox.shrink(key: ValueKey('empty')),
                        loading: () => const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) =>
                            Text('$e', key: const ValueKey('error')),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String levelLabel;
  final bool canUndo;
  final VoidCallback onBack;
  final VoidCallback onUndo;
  final VoidCallback onRestart;

  const _TopBar({
    required this.levelLabel,
    required this.canUndo,
    required this.onBack,
    required this.onUndo,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pill = isDark ? AppColors.pill : AppColors.lightPill;
    final onPill = isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _CircleButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: pill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              levelLabel,
              style: TextStyle(
                color: onPill,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          _CircleButton(icon: Icons.undo, enabled: canUndo, onTap: onUndo),
          const SizedBox(width: 10),
          _CircleButton(icon: Icons.refresh, onTap: onRestart),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final onSurface =
        isDark ? AppColors.onBackground : AppColors.lightOnBackground;
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(icon, color: onSurface, size: 20),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/game_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/game/screens/game_screen.dart test/presentation/game_screen_test.dart test/presentation/game_screen_test.mocks.dart
git commit -m "feat(front/presentation): custom top bar, animated switcher, restart wiring"
```

---

### Task 6.4: `LevelSelectionScreen` re-tematizado

**Files:**
- Modify: `lib/presentation/level_selection/level_selection_screen.dart` (reescritura)
- Test: `test/presentation/level_selection_screen_test.dart`

**Interfaces:**
- Consumes: `AppRouter.game`, `AppColors`, `LevelId`.
- Produces: `LevelSelectionScreen` (StatelessWidget) con rejilla de 12 niveles tipo píldora.

- [ ] **Step 1: Escribir el test que falla**

Crear `test/presentation/level_selection_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';

void main() {
  testWidgets('muestra el encabezado y 12 niveles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LevelSelectionScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Niveles'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verlo fallar**

Run: `flutter test test/presentation/level_selection_screen_test.dart`
Expected: FAIL — el encabezado aún dice "Select Level".

- [ ] **Step 3: Reescribir `level_selection_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/board/value_objects/level_id.dart';

/// Selector de nivel (12 niveles). Cada celda es una píldora que navega a la
/// partida. Presentación pura; la lista es estática por ahora.
class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  static const int _levelCount = 12;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.background : AppColors.lightBackground;
    final bgDeep =
        isDark ? AppColors.backgroundDeep : AppColors.lightBackgroundDeep;
    final pill = isDark ? AppColors.pill : AppColors.lightPill;
    final onBg = isDark ? AppColors.onBackground : AppColors.lightOnBackground;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.2,
            colors: [bg, bgDeep],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: onBg, size: 18),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    Text('Niveles',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: onBg,
                                  fontWeight: FontWeight.w800,
                                )),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _levelCount,
                  itemBuilder: (context, i) => InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRouter.game,
                      arguments: LevelId('${i + 1}'),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: pill,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: onBg,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test para verlo pasar**

Run: `flutter test test/presentation/level_selection_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Verificación final completa**

Run:
```bash
flutter analyze
flutter test
```
Expected: `analyze` sin errores; toda la suite en verde.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/level_selection/level_selection_screen.dart test/presentation/level_selection_screen_test.dart
git commit -m "feat(front/presentation): re-theme level selection (ES copy)"
```

---

> **Fin de Fase 6.** La app refleja los mockups (home, tablero, victoria) con tableros escalados por nivel. Verificación: `flutter analyze` limpio y `flutter test` (suite completa) en verde.

---

## Verificación final (todas las fases)

- [ ] `flutter analyze` sin errores ni warnings nuevos.
- [ ] `flutter test` — toda la suite en verde.
- [ ] Ejecutar la app (`flutter run`) y comprobar a mano: home animada → JUGAR → niveles → tablero (flechas gruesas multicolor, se toca la correcta, shake al bloquear, slide-out al salir) → victoria con nivel+movimientos. Niveles altos = tableros más grandes con más flechas.
- [ ] Tema claro/oscuro según el sistema (forzar ambos y revisar legibilidad de las flechas).





