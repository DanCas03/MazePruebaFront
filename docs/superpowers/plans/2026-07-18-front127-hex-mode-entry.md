# front#127 — Modo hexagonal: entrada en home, ruta /hex y fichas libres

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Superficie de UI del modo hexagonal: botón en Home, ruta `/hex` y pantalla de selección que pinta `view.hexTiles` (fichas libres, sin candados), navegando a la partida estándar. Cierra front#127.

**Architecture:** Espejo exacto del patrón temático (front#100). Todo el pipeline de datos ya existe (PR #129): `LevelSection.hex`, `CatalogView.hexTiles`, decoder y persistencia de score agnóstica de sección. Este plan solo toca `presentation/`, `core/router/` y l10n. Cero cambios en application/domain/infrastructure.

**Tech Stack:** Flutter, Riverpod (`levelSelectionControllerProvider`), rutas nombradas (`AppRouter`), gen_l10n (.arb), flutter_test.

## Global Constraints

- Regla de capas: `presentation/` solo consume providers de `application/` (vía la fachada `lib/presentation/providers/level_selection_provider.dart`).
- Conventional Commits, un commit por fragmento; rama `feat/#127-hex-mode-entry` desde `main` (8777c1f o posterior).
- Cada fragmento registra entrada en `AI_HISTORY.MD` (la siguiente es la **133**; máximo actual 132).
- Comentarios inline en español, mismo tono que los existentes (referenciar `front#127` / ADR-0007 D6).
- l10n: editar `lib/l10n/app_en.arb` y `lib/l10n/app_es.arb` y regenerar con `flutter gen-l10n` (los `app_localizations*.dart` son generados — no editarlos a mano).
- Suite completa verde al final: `flutter test`.
- Out of scope: leaderboard propio del modo, candados/progresión, onboarding 6-direcciones, mover el temático hexagonal (vive en la pantalla temática).

---

### Task 1: l10n + ruta `/hex` + `HexSelectionScreen` + test de widget

**Files:**
- Modify: `lib/l10n/app_en.arb` (tras el bloque `themedEmpty`, ~L138)
- Modify: `lib/l10n/app_es.arb` (tras `themedEmpty`, ~L53)
- Modify: `lib/core/router/app_router.dart` (constante + rama en `onGenerateRoute` + import)
- Create: `lib/presentation/level_selection/hex_selection_screen.dart`
- Test: `test/presentation/level_selection/hex_selection_screen_test.dart`

**Interfaces:**
- Consumes: `levelSelectionControllerProvider` (`AsyncValue<CatalogView>`, campo `hexTiles: List<LevelTile>`), `LevelTileGrid(tiles:)` de `widgets/level_tile_view.dart`, helpers de `test/support/level_selection_fakes.dart` (`levelSelectionOverrides({catalogEntries, progress})`).
- Produces: `class HexSelectionScreen extends ConsumerWidget` (ctor `const HexSelectionScreen({super.key})`), `AppRouter.hex == '/hex'`, claves l10n `hexSection`, `homeHex`, `hexEmpty`.

- [ ] **Step 1: Añadir claves l10n**

En `app_en.arb`, después del bloque de `themedEmpty`:

```json
  "hexSection": "Hex mode",
  "@hexSection": {
    "description": "AppBar title of the hexagonal mode selection screen (front#127, ADR-0007 D6)."
  },
  "homeHex": "Hex mode",
  "@homeHex": {
    "description": "Home screen CTA that opens the hexagonal mode section (front#127)."
  },
  "hexEmpty": "No hex levels available yet.",
  "@hexEmpty": {
    "description": "Empty state of the hex section when the catalog has no hex levels."
  },
```

En `app_es.arb`, después de `themedEmpty`:

```json
  "hexSection": "Modo hexagonal",
  "homeHex": "Modo hexagonal",
  "hexEmpty": "Aún no hay niveles hexagonales disponibles.",
```

Regenerar: `flutter gen-l10n` (desde `MazePruebaFront/`). Verificar que `lib/l10n/app_localizations.dart` ahora expone `hexSection`, `homeHex`, `hexEmpty`.

- [ ] **Step 2: Escribir el test de widget (fallará)**

Crear `test/presentation/level_selection/hex_selection_screen_test.dart` **espejando** `test/presentation/level_selection/themed_selection_screen_test.dart` (leerlo primero y copiar su `_NavCapture`/`_host`/`_pump` tal cual, cambiando la pantalla montada a `HexSelectionScreen` y la ruta observada `AppRouter.game`). Casos:

```dart
// Construir catalogEntries mixtos con el MISMO constructor de CatalogEntry que
// use themed_selection_screen_test.dart / level_selection_fakes.dart
// (copiar la forma exacta de allí), con secciones:
//   - 1 entry LevelSection.campaign
//   - 1 entry LevelSection.themed
//   - 3 entries LevelSection.hex (p. ej. ids 'hex-01', 'hex-02', 'hex-03')

testWidgets('should_list_exactly_hex_section_tiles_all_enabled', (tester) async {
  // Arrange: overrides con el catálogo mixto de arriba
  // Act: _pump(tester, nav, overrides)
  // Assert:
  //   - find.byType(LevelTileView) → 3 (ni campaña ni temáticos)
  //   - ninguna ficha bloqueada (mismo predicado que usa el test temático
  //     para candados, p. ej. find.byIcon(Icons.lock) → findsNothing)
});

testWidgets('should_navigate_to_game_with_real_level_id_on_tap', (tester) async {
  // Arrange: catálogo con 1 entry hex ('hex-01')
  // Act: tap sobre la ficha + pump
  // Assert: nav capturó AppRouter.game con arguments == LevelId('hex-01')
});

testWidgets('should_show_empty_state_when_no_hex_levels', (tester) async {
  // Arrange: catálogo solo con entries campaign/themed
  // Assert: find.text con l10n hexEmpty (resolver el literal como lo haga
  //   el test temático con themedEmpty)
});

testWidgets('should_show_error_state_when_catalog_fails', (tester) async {
  // Espejo del caso de error del test temático (StubLevelCatalog.withBuilder
  //   que lanza) → find.text(levelsLoadError)
});
```

Los cuerpos deben quedar completos copiando la mecánica exacta del test temático — mismo helper de overrides (`levelSelectionOverrides(catalogEntries: ..., progress: ...)`), mismo pump de 6 frames.

- [ ] **Step 3: Correr el test — debe fallar** (`flutter test test/presentation/level_selection/hex_selection_screen_test.dart`; esperado: no compila, `HexSelectionScreen` no existe).

- [ ] **Step 4: Implementar pantalla + ruta**

`lib/presentation/level_selection/hex_selection_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../providers/level_selection_provider.dart';
import 'widgets/level_tile_view.dart';

/// Modo hexagonal (front#127, ADR-0007 D6): pantalla propia para las fichas
/// libres de la sección `hex` del catálogo. Espejo del patrón temático
/// (front#100): consume el MISMO estado resuelto (`levelSelectionControllerProvider`)
/// y pinta solo su bloque `hexTiles` — todas jugables desde el inicio, sin
/// candados ni orden. Navega a la partida estándar con el LevelId REAL; el
/// score fluye al leaderboard general por la tubería existente, sin cambios.
///
/// Se empuja SOBRE Home: el `leading` implícito del AppBar garantiza la vuelta
/// al menú principal (front#96/#103).
class HexSelectionScreen extends ConsumerWidget {
  const HexSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surface : AppColors.lightSurface;
    final sections = ref.watch(levelSelectionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hexSection),
        backgroundColor: surface,
      ),
      body: sections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.levelsLoadError, textAlign: TextAlign.center),
          ),
        ),
        data: (view) => view.hexTiles.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.hexEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [LevelTileGrid(tiles: view.hexTiles)],
              ),
      ),
    );
  }
}
```

En `lib/core/router/app_router.dart`:

```dart
// import junto a los demás de level_selection:
import '../../presentation/level_selection/hex_selection_screen.dart';

// constante, tras `themed`:
  // front#127: modo hexagonal, alcanzable desde el menú principal (ADR-0007 D6).
  static const String hex = '/hex';

// rama en onGenerateRoute, tras la de themed:
      AppRouter.hex => _fade(const HexSelectionScreen(), settings),
```

- [ ] **Step 5: Correr el test — debe pasar** (`flutter test test/presentation/level_selection/hex_selection_screen_test.dart`; esperado: PASS 4/4).

- [ ] **Step 6: AI_HISTORY Entrada 133** (fecha 2026-07-18, tarea front#127 pantalla+ruta+l10n, prompt del brief, resultado) y commit:

```bash
git add lib/l10n lib/core/router/app_router.dart lib/presentation/level_selection/hex_selection_screen.dart test/presentation/level_selection/hex_selection_screen_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add hex mode selection screen with /hex route (#127)"
```

---

### Task 2: Botón «Modo hexagonal» en Home + test

**Files:**
- Modify: `lib/presentation/home/screens/home_screen.dart` (insertar botón entre el bloque temático, que termina ~L125, y el `SizedBox(height: 16)` previo al generador)
- Modify (test): `test/presentation/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `AppRouter.hex` y `HexSelectionScreen` (Task 1), clave l10n `homeHex`, helpers `levelSelectionOverrides` del test de home existente.
- Produces: `OutlinedButton` con texto `l10n.homeHex` en Home que navega a `AppRouter.hex`.

- [ ] **Step 1: Test de widget (fallará)** — en `test/presentation/home/home_screen_test.dart`, espejo del caso existente del botón temático (mismo host/overrides):

```dart
testWidgets('should_show_hex_mode_entry_and_navigate_to_hex_screen', (tester) async {
  // Arrange: mismo montaje que el caso 'Niveles temáticos' existente
  // Act: tap en find.widgetWithText(OutlinedButton, 'Modo hexagonal')
  //   (ensureVisible antes del tap si el caso temático lo hace)
  // Assert: find.byType(HexSelectionScreen) → findsOneWidget
});
```

- [ ] **Step 2: Correr — debe fallar** (`flutter test test/presentation/home/home_screen_test.dart`; esperado: FAIL, botón no encontrado).

- [ ] **Step 3: Añadir el botón** en `home_screen.dart`, tras el `OutlinedButton.icon` temático (después de su cierre `),` ~L125) y antes del `const SizedBox(height: 16)` del generador:

```dart
                const SizedBox(height: 16),
                // front#127: acceso al modo hexagonal (fichas libres, ADR-0007
                // D6). Secundario contorneado, mismo molde que el temático.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRouter.hex),
                  icon: const Icon(Icons.hexagon_outlined),
                  label: Text(
                    l10n.homeHex,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
```

Si la columna desborda en los tests de home (surface fija), envolver la `Column` central igual que lo resuelva el propio test (o ajustar el surface del test como hace el temático a 500x1200) — no cambiar el layout de producción salvo desborde real.

- [ ] **Step 4: Correr — debe pasar** (`flutter test test/presentation/home/home_screen_test.dart`; PASS todos, incluidos los previos).

- [ ] **Step 5: AI_HISTORY Entrada 134 + commit**

```bash
git add lib/presentation/home/screens/home_screen.dart test/presentation/home/home_screen_test.dart AI_HISTORY.MD
git commit -m "feat(presentation): add hex mode entry button on home screen (#127)"
```

---

### Task 3: Test AAA de persistencia con nivel hex + suite completa + README

**Files:**
- Test: `test/application/providers/progress_providers_hex_test.dart` (o añadir caso al test existente de `levelCompletionObserverProvider` si existe — buscarlo con Grep `levelCompletionObserver` en `test/` y espejar su montaje)
- Modify: `README.md` (sección de pantallas/rutas: añadir `/hex` y la entrada del modo)

**Interfaces:**
- Consumes: `levelCompletionObserverProvider`, `gameControllerProvider`, `RecordLevelCompletionUseCase`, `FakeLevelProgressRepository`.
- Produces: evidencia AAA de que completar un nivel de sección hex persiste por el mismo camino que la campaña (criterio de aceptación 3 del brief).

- [ ] **Step 1: Escribir el test AAA** — localizar el test existente del observer de completado (Grep `levelCompletionObserver` bajo `test/`) y añadir/espejar un caso donde el `levelId` es de un nivel hex (p. ej. `LevelId('hex-01')`):

```dart
test('should_persist_progress_for_hex_level_via_standard_pipeline', () async {
  // Arrange: mismo montaje que el caso campaña del observer, con
  //   FakeLevelProgressRepository vacío y levelId LevelId('hex-01')
  // Act: emitir el borde GameWon como lo haga el caso existente
  // Assert: el repo contiene LevelProgress para 'hex-01' con stars/score
});
```

Nota: si el pipeline ya está cubierto de forma agnóstica y montar el observer aislado no es viable con los fakes existentes, el fallback aceptable es el test e2e de la Entrada 132 (`test/` de flujo completo sobre nivel hex) — en ese caso documentar en AI_HISTORY por qué el criterio queda cubierto por ese test y no añadir uno redundante.

- [ ] **Step 2: Correr el test nuevo** — PASS (o justificar fallback).

- [ ] **Step 3: Suite completa**: `flutter test` → todo verde. `flutter analyze` → sin issues nuevos.

- [ ] **Step 4: README** — en `MazePruebaFront/README.md`, añadir el modo hexagonal donde se listan las pantallas/rutas (espejo de cómo se documentó la sección temática): entrada en home, ruta `/hex`, fichas libres sin progresión, score al leaderboard general.

- [ ] **Step 5: AI_HISTORY Entrada 135 + commit + PR**

```bash
git add test/ README.md AI_HISTORY.MD
git commit -m "test(front): cover hex level completion persistence via standard pipeline (#127)"
git push -u origin feat/#127-hex-mode-entry
gh pr create --base main --title "feat(presentation): hex mode entry, /hex route and free tiles (#127)" --body "Closes #127 ..."
```

El body del PR debe listar: qué llegó con #129 (datos) vs qué añade este PR (presentación), criterios de aceptación con checkboxes, y nota de que el flujo manual e2e (home → hex → ficha → victoria → leaderboard) queda pendiente de verificación del mantenedor con el back sirviendo la sección hex (back PR #63).
