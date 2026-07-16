# Generador: densidad homogénea por bandas concéntricas

**Fecha:** 2026-07-15
**Alcance:** `MazePruebaFront` — `GraphBoardGenerator.generate()` (infraestructura). Afecta a ambos consumidores del generador: el modo "Generar nivel" de la app y el tooling de producción (`tool/level_production`). Los niveles de campaña ya producidos son JSON estático y no cambian salvo re-producción deliberada.

## Problema

En tableros grandes, los niveles generados concentran las flechas en el perímetro y dejan el centro casi vacío (patrón de anillo). Causa estructural: `_randomBentArrow` elige primero una dirección y luego una cabeza cuyo carril recto hasta el borde esté 100% libre. La probabilidad de carril libre decae exponencialmente con su longitud, así que con ocupación creciente solo sobreviven cabezas pegadas a su borde de salida.

## Objetivo

Cobertura aproximadamente homogénea: la densidad de celdas ocupadas en el interior es comparable a la del perímetro. Cambio contenido ("nada excesivo"), sin knobs públicos nuevos.

## Decisiones (brainstorm 2026-07-15)

- Enfoque elegido: **interior primero, por bandas con cuota** (opción 2), incluyendo elección de dirección factible dentro de cada banda. Descartadas: solo dirección factible (mejora parcial) y bias con temperatura (tuning y testeo difíciles).
- Validación: test estadístico de densidad por bandas + inspección visual del usuario.

## Diseño

### Qué NO cambia

- Puerto `ILevelGenerator`, `GeneratorConfig`, firma de `generate()`.
- `generateThemed()` y su camino de rng: **byte-estable**; su golden inline (`themed_producer_test.dart`, seed 0) debe seguir verde sin recaptura — es la prueba de aislamiento.
- Invariante DAG (solubilidad por construcción): cada candidata sigue exigiendo carril de salida libre sobre `occupied` global en el momento de colocarla; los asserts existentes se conservan.
- Crecimiento del cuerpo: caminata auto-evitante hacia atrás, carril reservado, sin confinar el cuerpo a la banda (solo la cabeza se ancla; confinar cuerpos es propio de regiones temáticas).
- Determinismo: `Random(seed)` ⇒ mismo seed, mismo tablero. (Un seed dado produce un tablero distinto al de antes del cambio; aceptado.)

### Mecánica nueva en `generate()`

1. **Bandas**: distancia al borde `d = min(row, col, rows-1-row, cols-1-col)`, `maxD = (min(rows, cols) - 1) ~/ 2`. El rango `[0..maxD]` se divide en `k = min(3, maxD + 1)` bandas de ancho igual. Tableros pequeños degeneran a 1–2 bandas (≈ comportamiento actual).
2. **Cuota por banda** ∝ nº de celdas de la banda, redondeo por **mayor resto** (la suma es exactamente `arrowCount`). La cuota se calcula en un helper puro testeable.
3. **Orden**: de la banda interior a la exterior. Las flechas centrales se colocan con el tablero vacío (carriles largos baratos); el perímetro se llena al final, cuando solo los carriles cortos son viables. Homogeneidad por construcción. El orden de resolución (inverso al de colocación) pela el tablero de fuera hacia dentro.
4. **Dentro de cada banda**: se muestrea la cabeza del pool de celdas de la banda (hasta 20 intentos, saltando ocupadas); se calculan las direcciones con carril libre y se elige una al azar **entre las factibles** (hoy la dirección se impone a priori).
5. **Presupuesto**: `celdas_banda × 30` intentos por banda (suma global = `cols × rows × 30`, igual que hoy). La cuota no colocada **rueda a la banda siguiente hacia fuera**; el déficit final usa el `_logger?.warn` de degradación con gracia existente.

### Casos límite

- Tableros mínimos (`maxD = 0`): una sola banda; solo cambia la elección cabeza→dirección.
- `arrowCount` mayor que la capacidad: degradación con gracia, como hoy.
- `maxPathLen` se respeta sin cambios.

## Tests

- **Nuevo** `test/infrastructure/generators/graph_board_density_test.dart`: ~5 seeds en 20×20 con `arrowCount` tipo rampa; densidad de ocupación por banda; assert `densidad_interior ≥ 0.6 × densidad_global`. Debe estar rojo con el generador actual y verde con el nuevo.
- **Nuevo** test unitario del helper puro de cuotas (mayor resto, rollover).
- **Golden de campaña** (`golden_boards_regression_test.dart`): rompe por diseño (su misión pre-BoardSpace terminó con el merge de PR #79). Se recapturan los dos fixtures con el generador nuevo y el comentario del test pasa a describir un *forward regression guard* (patrón back#39).
- **Deben seguir verdes sin cambios**: invariantes de `graph_board_generator_test.dart`, `graph_board_themed_test.dart`, golden temático de `themed_producer_test.dart`, determinismo (`level_generation_determinism_test.dart`) y perf 50×50 (`graph_board_generator_perf_test.dart`).

## Proceso

Rama `feat/generator-band-density` desde `main`, commits convencionales por fragmento con su entrada AI_HISTORY (siguiente ≈ 086; verificar al ejecutar), nota breve en README (§ modo generado) sobre la distribución homogénea, PR a `main` (el usuario decide el merge). En el plan de implementación los tests se delegan a un subagente con prompt específico.
