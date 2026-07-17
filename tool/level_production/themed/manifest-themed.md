# Manifiesto de niveles temáticos (front#68)

Generado por `dart run tool/level_production/produce_themed.dart`.
Curación: revisar `<levelId>.preview.txt` para juzgar si la figura se reconoce.

## Lote — seeds 0..150 · objetivo 90% · maxlen 8

| figura | dims | seed usado | flechas colocadas | cobertura por rol | objetivo alcanzado | timeLimitSec |
|---|---|---|---|---|---|---|
| themed-bunny | 16×20 | 11 | 37 | fur:86% pink:88% eye:100% | no | ninguno |
| themed-happy_face | 16×16 | 31 | 38 | face:81% features:100% | no | ninguno |
| themed-heart | 16×14 | 11 | 23 | heart:91% | sí | ninguno |

Incidencias (regiones bajo objetivo / errores):
- themed-bunny: región `fur` bajo objetivo (86% < 90%)
- themed-bunny: región `pink` bajo objetivo (88% < 90%)
- themed-happy_face: región `face` bajo objetivo (81% < 90%)

## Lote — seeds 0..150 · objetivo 90% · maxlen 8

| figura | dims | seed usado | flechas colocadas | cobertura por rol | objetivo alcanzado | timeLimitSec |
|---|---|---|---|---|---|---|
| themed-happy_face | 24×22 | 94 | 72 | face:72% features:86% | no | ninguno |
| themed-heart | 24×16 | 74 | 51 | heart:82% | no | ninguno |

Incidencias (regiones bajo objetivo / errores):
- themed-happy_face: región `face` bajo objetivo (72% < 90%)
- themed-happy_face: región `features` bajo objetivo (86% < 90%)
- themed-heart: región `heart` bajo objetivo (82% < 90%)

## Lote — modo denso (#118) · seeds 0..99 · objetivo 90%

Dos corridas `--mask` (heart, happy_face) fusionadas a mano en una sección.
Selección de seed = criterio de los guardianes (detalle al 100% → profundidad
máxima de hueco <= 2 → mayor cobertura), NO cobertura sola. Los JSON emiten
`silhouette` (fill completo de la máscara). `themed-bunny` está CONGELADO
(benchmark estético): no se regeneró, solo ganó `silhouette` vía
`add_silhouette.dart` — sus 37 flechas quedan byte-idénticas.

| figura | dims | seed usado | flechas colocadas | cobertura por rol | objetivo alcanzado | timeLimitSec |
|---|---|---|---|---|---|---|
| themed-heart | 36×24 | 67 | 190 | heart:99% | sí | ninguno |
| themed-happy_face | 24×22 | 41 | 129 | face:98% features:100% | sí | ninguno |

