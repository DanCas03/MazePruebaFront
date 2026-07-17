# Diseño: tablero temático enmascarado con relleno denso (rediseño)

**Fecha:** 2026-07-16
**Estado:** aprobado por el maintainer (conversación 2026-07-16)
**Artefactos:** MazePruebaFront + MazePruebaBack (cross-repo)
**Supersede:** front#114 / PR #115 y back#50 / PR #51 (descartados: el generador `generateThemedFull` degeneró en flechas rectas apiladas y el render "solo flechas, sin fondo" no logró el tablero esperado). **Nada de esas ramas se reutiliza.**

---

## 1. Problema

Tras el PR #107 (issue #99), todos los niveles —temáticos incluidos— se montan sobre su `RectSpace` completo: el tablero temático es un rectángulo y la figura solo se insinúa por los colores de las flechas. La producción temática actual cubre ~72-83% de la máscara, así que además la figura tiene huecos (especialmente notorios en el centro de la cara feliz tras su ampliación a 24×22).

Decisión del maintainer (2026-07-16), que revierte la aceptación del rectángulo registrada en #99:

1. **Prioridad #1: la silueta del tablero ES la figura.** Fuera de ella no se dibuja nada (ni superficie, ni grid) y no se aceptan taps.
2. **Dentro de la silueta todo es tablero**: superficie pintada sin huecos; las celdas sin flecha se ven como tablero, no como vacío.
3. **Densidad de flechas claramente superior a la actual**, con flechas variadas (con codos) — nunca columnas de flechas rectas.
4. Los niveles temáticos **no participan de la banda 9:16** de campaña/generados: cada máscara conserva su proporción propia.

## 2. Alcance

- **Front:** dominio (campo `silhouette` en `Level`), decoder estricto, montaje `MaskedSpace` para temáticos, painter de superficie limitado al espacio, tooling de producción temática (generador nuevo + máscara nueva del corazón), fixtures regenerados.
- **Back:** campo `silhouette` en el wire (entidad, mapper, Prisma JSON), validación en seed, seeds temáticos regenerados.
- **Sin cambios:** campaña y generados (montaje, banda 9:16, goldens), scoring/timer, mecánica de flechas, solver.

## 3. La máscara viaja en el wire

El seed de cada nivel temático incluye un campo `silhouette`:

```json
"silhouette": {
  "<paintRole>": [[row, col], ...]
}
```

- Contiene **todas las celdas del fill** de cada región de la figura (tengan flecha o no). La unión de todas las regiones define el espacio del tablero.
- **Back:** la entidad de dominio y el mapper lo exponen tal cual (opaco); el seed valida que (a) toda celda de toda flecha pertenece a la silueta, (b) toda celda de silueta está dentro de `cols × rows`, (c) las regiones no se solapan.
- **Front:** el decoder es **estricto para la sección temática** (silhouette requerido y bien formado; rechaza formas inválidas). Campaña no lleva el campo y no lo requiere.

## 4. Render (front)

- `_mountedBoard`: si el nivel trae `silhouette`, monta `MaskedSpace(box: cols×rows, activeCells: unión de la silueta)`. Si no, `RectSpace` como hoy. Esto revierte quirúrgicamente la decisión "caja completa" del PR #107 **solo para temáticos**.
- El painter de superficie pinta superficie + grid **únicamente en celdas del espacio**; fuera de la silueta queda el fondo de la app.
- Hit-testing ya es space-aware (front#87): los taps fuera de la silueta se rechazan por construcción.
- La animación de salida de una flecha puede cruzar celdas enmascaradas hasta el borde de la caja: se mantiene tal cual (cosmético; si molesta en la práctica se abre issue aparte).

## 5. Generador nuevo (tooling front)

Rellenador de máscaras con **reglas duras, cada una con test guardián** para impedir la degeneración del intento anterior:

| Regla | Criterio | Guardián |
|---|---|---|
| Variedad | Longitudes 2-5 celdas mezcladas; ≥40% de las flechas con ≥1 codo; sin columnas/filas de ≥3 flechas rectas paralelas adyacentes | test sobre el fixture generado |
| Densidad global | ≥90% de las celdas de la máscara con flecha (antes: 72-83%) | test por máscara |
| Detalles al 100% | Las regiones de detalle (ojos, boca, nariz, orejas internas) quedan 100% cubiertas; si una celda de detalle es irrellenable con flechas ≥2 celdas, se ajusta la geometría de la máscara — no se deja el hueco | test por región de detalle |
| Huecos al borde | Las celdas residuales sin flecha se sitúan hacia el borde de las regiones grandes, nunca en el centro de la figura (métrica: distancia media de los huecos al borde de su región ≤ umbral, valor fijado durante la implementación al calibrar con la cara feliz) | test sobre el fixture |
| Solvencia | El nivel resultante es resoluble (invariante DAG, verificado con el solver existente) | test existente + golden |

Los guardianes aplican a los fixtures **regenerados** (corazón, cara feliz). El conejo no se regenera: queda congelado con un test de caracterización (sus flechas no cambian).

**Benchmark estético:** el conejo actual (`themed-bunny`, 16×20, 37 flechas) — el maintainer lo considera perfecto. El generador nuevo debe producir esa sensación en corazón y cara feliz.

## 6. Máscaras y fixtures

| Nivel | Máscara | Acción |
|---|---|---|
| Conejo | 16×20 (actual) | **Se conserva tal cual: mismas flechas, misma máscara.** Solo se le añade el campo `silhouette` (derivado de su máscara) al fixture/seed. |
| Corazón | nueva, ~36×24 | Redibujar la máscara más grande; regenerar con el generador nuevo. |
| Cara feliz | 24×22 (actual) | Regenerar con el generador nuevo (más densidad, cara 100% cubierta). |

Los fixtures del front (`tool/level_production/themed/`) y los seeds del back (`prisma/levels/t-*.json`) se regeneran juntos y deben ser semánticamente idénticos (mismo levelId, dims, flechas, silhouette).

## 7. Testing (AAA en ambos artefactos)

- **Front:** decoder (estricto, round-trip), entidad `Level` con silhouette, montaje MaskedSpace desde silhouette, painter pinta solo el espacio, guardianes del generador (tabla §5), widget test de un temático sin celdas pintadas fuera de la silueta.
- **Back:** entidad/mapper con silhouette, validaciones de seed (flecha fuera de silueta ⇒ error), e2e de que el API sirve el campo.

## 8. Ejecución

- Issues y ramas **nuevas** en ambos repos; cerrar PR #115 (front) y PR #51 (back) como superseded (decisión del usuario).
- Orden: tooling/generador front → fixtures → wire back → render front (el render puede desarrollarse contra fixtures locales antes de que el back sirva el campo).
- Commits por fragmento con entrada en AI_HISTORY, Conventional Commits, READMEs actualizados donde cambie funcionalidad pública.
