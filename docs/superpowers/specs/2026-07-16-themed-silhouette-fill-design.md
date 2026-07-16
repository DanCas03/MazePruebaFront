# Diseño — Relleno de silueta temática (sin huecos visibles)

**Fecha:** 2026-07-16
**Autor:** Claude (rol frontend/backend architect) + revisión del mantenedor
**Estado:** BORRADOR — pendiente de aprobación del mantenedor
**Repos afectados:** `MazePruebaFront/` (tooling + render) y `MazePruebaBack/` (seed + fixtures + contrato)
**Relación:** encima de back#47 / front#112 (máscaras a mayor resolución, PRs #49 / #113). Esto NO reemplaza esos PRs; añade la capa de silueta.

---

## 1. Problema

Los niveles temáticos (`t-heart`, `t-happy-face`, `t-bunny`) se rellenan con flechas rectas.
El generador (`GraphBoardGenerator.generateThemed`) coloca cada flecha con un carril de
salida libre (invariante DAG = solubilidad por construcción). Eso impone un **techo de
cobertura estructural** muy por debajo del 100 %:

| figura | cobertura actual | techo medido (seeds 0..400, maxlen 8) |
|---|---|---|
| heart | 82 % | ~83 % |
| happy-face | face 72 % / features 86 % | face ~72 % |
| bunny | fur 86 % / pink 88 % / eye 100 % | — |

Las celdas de la figura **sin** flecha se renderizan como fondo neutro (no hay color por
región en ningún lado), así que la figura se ve "agujereada". Subir la cobertura solo con
parámetros (maxlen, semillas) **no** resuelve el problema.

**Decisión del mantenedor (2026-07-16):** completar los huecos por **relleno visual
(silueta)**, no por más flechas. Es decir: pintar cada celda de la figura con el color de
su región, aunque no tenga flecha.

## 2. Hallazgo que amplía el alcance

El wire actual **no transporta la máscara**. `CONTEXT.md` lo documenta como decisión de
dominio: *"La máscara no viaja en el wire — solo sus consecuencias (las instrucciones de
pintado)."* El nivel servido por la API solo trae `cols/rows`, `palette` (rol→hex),
`arrows[]` con `paintRole`. El cliente **no sabe** qué celdas forman cada región de color.

`MaskedSpace` (geometría de silueta) existe en el dominio pero front#99 la desconectó de
producción: el tablero temático se monta como `RectSpace` completo con un `surfaceColor`
neutro único (`BoardSurfacePainter`).

**Consecuencia:** para pintar la silueta hay que **serializar un dato nuevo** (las celdas
de cada región) → cambio **cross-repo** que **revisa** la decisión "la máscara no viaja en
el wire". Es de bajo riesgo *técnico* (dato opaco, no toca solubilidad ni mecánica), pero
no es un cambio front-only trivial. El mantenedor aceptó este alcance.

## 3. Enfoque elegido (y descartados)

- **ELEGIDO — Silueta visual.** Serializar por rol las celdas de la región; pintarlas
  tenues bajo las flechas. Garantiza figura sin huecos visibles. Cross-repo, no toca
  solubilidad.
- Descartado — Post-relleno de flechas reales (~95 %): front-only, no toca wire, pero no
  garantiza 100 % y cambia el "look" (más flechas cortas).
- Descartado — Reescribir la generación para cobertura total (~100 % real): mayor
  esfuerzo/riesgo; puede exigir relajar reglas (flechas de 1 celda).

## 4. Contrato / wire (lo nuevo)

Campo opcional en el JSON del nivel, hermano de `palette`:

```json
"silhouette": {
  "heart": [[3,4],[3,5],[3,6]]
}
```

- Clave = rol de pintado (debe existir en `palette`).
- Valor = **todas** las celdas `[row, col]` de esa región de la máscara (superset de las
  celdas ocupadas por flechas de ese rol).
- **Opaco**: no afecta mecánica ni solubilidad. Ausente ⇒ nivel de campaña sin cambios
  (aditivo, OCP).
- Orden estable: se emite después de `palette` para preservar la golden property
  encode∘decode.

## 5. Cambios por componente

### 5.1 Front — producción (tooling)
- `lib/infrastructure/serialization/level_json_encoder.dart`: nuevo parámetro opcional
  `Map<String, List<Position>>? silhouette`; se emite solo si no es null (campaña no lo
  pasa). `toMap` y `encode`.
- `tool/level_production/themed_producer.dart`: construir `silhouette` desde
  `mask.regions` (rol→cells, en orden de leyenda) y pasarlo al encoder.
- Regenerar los 3 fixtures temáticos con los MISMOS parámetros de lote (coverage 0.9,
  seeds 0..150, maxlen 8). heart/happy-face: semillas 74/94 → flechas idénticas + campo
  nuevo. bunny: seed 11 → flechas idénticas + campo nuevo (el fixture cambia solo por
  añadir `silhouette`).

### 5.2 Back
- `prisma/seed.ts`: `LevelFixture` +`silhouette?: Record<string, [number, number][]>`;
  `toData` lo iza a `data` igual que `palette`.
- `src/infrastructure/database/level-paint.validator.ts`: chequeo barato — cada rol de
  `silhouette` existe en `palette`; cada celda está in-bounds (`0<=row<rows`,
  `0<=col<cols`). Falla fail-fast como el resto del guardrail.
- Fixtures `prisma/levels/t-{heart,happy-face,bunny}.json` regenerados (con `silhouette`).
- `prisma/levels/manifest.md`: nota de que los temáticos ahora incluyen silueta.
- `CONTEXT.md` (y front `CONTEXT.md` si aplica) + **ADR nuevo**: revisar la decisión "la
  máscara no viaja en el wire" → su silueta sí viaja como consecuencia de pintado.

### 5.3 Front — render
- `lib/infrastructure/serialization/level_json_decoder.dart`: parsear `silhouette`
  (`Map<String, List<Position>>?`), estricto (forma inválida → FormatException).
- `lib/domain/board/entities/level.dart`: campo `silhouette` (nullable), análogo a
  `palette`.
- `lib/application/state/...` (GameState/GameController): exponer `silhouette` al widget,
  igual que hoy expone `palette`.
- `lib/presentation/game/painters/board_surface_painter.dart`: pintar cada celda de
  `silhouette[role]` con `parseHexColor(palette[role])` a **alpha 0.30** (default,
  afinable); las celdas fuera de la figura conservan el `surfaceColor` neutro. La silueta
  va **debajo** de las flechas (las flechas se pintan a color pleno encima).
- `lib/presentation/game/widgets/board_widget.dart`: pasar `silhouette` + `palette` al
  painter.

## 6. Invariantes que NO cambian
- `_mountedBoard` sigue montando `RectSpace` completo. La silueta es solo pintura.
- Solubilidad, colocación de flechas, mecánica de salida: intactas.
- Las celdas de silueta sin flecha **no** son jugables (no hay flecha que tocar); solo se
  pintan. Es relleno visual, no geometría.

## 7. Tests
- Front encoder/decoder: round-trip con `silhouette`; decoder rechaza forma inválida.
- Front `Level`: guarda la silueta.
- Front painter: celda de silueta sin flecha se pinta con color de rol a alpha reducido;
  celda fuera de la figura queda neutra; la flecha encima va a color pleno.
- Back `curated-levels.spec.ts`: silueta válida (roles ⊆ palette, celdas in-bounds); un
  fixture con rol/celda inválida es rechazado.

## 8. Ramas / PRs (cross-repo)
- Nuevo issue en cada repo (front + back), rama `feat/#N-<slug>` por repo.
- 2 PRs, **sin auto-merge** (los mergea el compañero).
- Independientes de #113 / #49.

## 9. Parámetro abierto
- **Opacidad de la silueta:** default propuesto **0.30** del color de región. Se afina
  visualmente al ver las figuras en la app (no bloquea el diseño).

## 10. Riesgos
- Revisa una decisión de contrato documentada → requiere actualizar CONTEXT.md + ADR para
  no dejar el repo contradiciéndose.
- Tamaño de fixture: +~1–2 KB por figura (lista de celdas). Aceptable.
- Golden property encode∘decode: el orden y forma del campo deben ser deterministas
  (cubierto por tests de round-trip).
