# Arrow Maze — Cliente de Juego (Flutter)

Contexto del **motor de juego jugable**: corre la mecánica "serpiente", renderiza el
tablero, lleva el estado de la partida y persiste/sincroniza el progreso. Los niveles
los **define el backend**; aquí se consumen y se juegan.

## Language

### Mecánica de flechas

**Arrow** (Flecha):
Un camino de celdas ortogonalmente adyacentes, de la cola (`tail`, primera) a la cabeza
(`head`, última); puede doblar (mecánica serpiente). Una flecha recta es el caso degenerado.
_Avoid_: pieza, bloque, "flecha recta" como tipo aparte.

**headDirection** (dirección de cabeza):
Dirección por la que la cabeza abandona el tablero; al salir, el cuerpo se retrae por su
propio camino, así que la salida solo depende del carril recto frente a la cabeza.
_Avoid_: rotación, orientación, giro.

**ArrowBoard** (Tablero):
Aggregate root y único punto de acceso al estado del tablero (lista de `Arrow` + `cols`/`rows`).
Nadie toca un `Arrow` desde fuera del tablero. El Tablero son flechas *sobre* un BoardSpace.
_Avoid_: grid, grilla, matriz de celdas, board de celdas.

**BoardSpace** (Espacio del tablero):
La geometría del tablero como concepto propio: qué celdas existen, cuáles son adyacentes,
qué es un carril recto y dónde está la **frontera** por la que una flecha sale. Es el único
intérprete de las direcciones. El espacio de la campaña es rectangular (`cols`×`rows`); un
espacio distinto (agujereado, 3D) cambia la geometría sin cambiar la mecánica de juego.
_Avoid_: grid, plano, matriz, dimensiones sueltas como sinónimo de geometría.

**exit path** (carril de salida):
Celdas que la cabeza debe recorrer en línea recta hasta la frontera del espacio para que la
flecha salga (en el tablero rectangular, el borde). Si todas están libres de otras flechas,
la flecha puede salir.
_Avoid_: camino de movimiento, ruta del jugador.

**Exit / Remove** (salida / remoción):
Tocar una flecha cuyo carril está libre la elimina permanentemente del tablero.
_Avoid_: mover, deslizar al jugador, rotar, activar.

**Collision** (Choque):
Tocar una flecha cuyo carril está bloqueado por otra: no sale, dispara el _shake_ y cuenta
como movimiento erróneo.
_Avoid_: fallo, bloqueo a secas.

**Strike** (Error acumulado):
Un choque contabilizado. Al alcanzar **5**, la partida se pierde.
_Avoid_: vida, intento, fallo.

**Cleared** (Victoria):
Tablero sin flechas (`isCleared`).
_Avoid_: ganado, resuelto.

**MoveCount** (Movimientos):
Número de toques válidos de la partida; insumo del scoring.

### Estado del juego

**GameState**:
Estado sellado y mutuamente excluyente de la partida: `GameLoading`, `GamePlaying`,
`GameWon`, `GameLost`.
_Avoid_: pantalla, fase, modo.

**TimeLimit** (Límite de tiempo):
Tope de tiempo de un nivel; agotarlo → `GameLost`. **Obligatorio en todo `Level`** desde
2026-07-16 (antes opcional; los niveles se regeneran). Sigue siendo opcional en un
`GeneratedBoard` (timer a elección del jugador).

**Par** (Tiempo de referencia):
"Qué es un buen tiempo" en un nivel: la mitad de su TimeLimit. El Score pondera la
velocidad del jugador contra el Par — por debajo premia, cerca del límite castiga.
_Avoid_: TimeLimit como sinónimo (ese es "cuándo pierdes", no "qué es rápido").

### Nivel y progreso

**Level / LevelId**:
Definición de un nivel (dimensiones + flechas) identificada por `LevelId`, **obtenida del
backend**. El cliente no genera los niveles oficiales.
_Avoid_: mapa, stage, pantalla.

**Catálogo (de niveles)**:
Lista ordenada de `LevelId` que el backend publica; su orden **es** el orden de juego de la
campaña. "Siguiente nivel" significa el siguiente `LevelId` del Catálogo, nunca aritmética
sobre el id. El último elemento no tiene siguiente.
_Avoid_: lista de niveles, índice, mapa de campaña.

**Sección (del Catálogo)**:
Partición del Catálogo que publica el backend: **campaña** (ordenada, con gating por Tier,
"siguiente nivel" = adyacencia) y **temático** (sin gating ni orden de juego, jugable desde
el inicio). Un `Level` pertenece a exactamente una sección.
_Avoid_: categoría, modo, mundo.

**Nivel temático**:
`Level` curado cuyo tablero dibuja una figura reconocible (cara feliz, conejito, …). Vive en
la sección temático del Catálogo; puntúa y persiste `Progress`/`Leaderboard` como cualquier
`Level`. Lleva Instrucciones de pintado.
_Avoid_: nivel especial, skin, easter egg.

**Instrucciones de pintado**:
Metadata visual opcional de un `Level`: una paleta de roles de color más un rol por flecha.
El cliente resuelve rol→color según el tema visual activo; sin instrucciones, el color sale
de la paleta por identidad (default). No afectan la mecánica ni la solubilidad.
_Avoid_: colores hardcodeados, tematización del cliente.

**GeneratedBoard** (Tablero generado):
`ArrowBoard` creado **localmente** por el generador con parámetros elegidos por el jugador
(dimensiones, preset de dificultad, timer opcional, seed opcional); soluble por construcción.
Efímero: no es un `Level` (no tiene `LevelId`), no puntúa, no persiste `Progress` ni participa
del `Leaderboard`. Reproducible por (seed, parámetros) **dentro de una misma versión de la
app**. "Generar nivel" es solo el copy de UI de la feature.
_Avoid_: nivel generado, nivel random, nivel de práctica, modo práctica, Candidato.

**Progress** (Progreso):
Por nivel: completado, mejores estrellas y mejor score. Se guarda local (Hive) y se
sincroniza con el backend.

**Stars** (Estrellas):
1–3 por nivel, según choques y movimientos respecto del óptimo.

**Score** (Puntaje):
Valor numérico = f(tiempo respecto del Par, movimientos sobre óptimo, choques);
**multiplicativo**, para que rápido-y-perfecto se separe con claridad de "pasar con lo
mínimo". El que calcula el cliente es un **preview** (feedback inmediato / offline); el
canónico lo deriva el backend de las métricas del run y reconcilia la pantalla de victoria
al llegar (decidido 2026-07-16).
_Avoid_: score del cliente como fuente de verdad.

**Solution** (Solución):
El orden de `ArrowId`, producido y servido por el **backend**, cuya remoción en secuencia
vacía el tablero. El cliente la **anima**; nunca deriva el orden (ADR 0002).
_Avoid_: respuesta, walkthrough, camino ganador.

**Auto-solver** (antes "Hint"/Pista, #102):
Demo **no puntuada** disponible en **todo** nivel de campaña y en los temáticos:
reinicia el nivel y reproduce la Solución animada. Explícitamente presentada como
auto-solver (no una ayuda vaga) y exige **confirmación** del jugador antes de correr
—el progreso del intento en curso se pierde—. El ritmo entre pasos **escala con el
número de flechas** (más flechas ⇒ pasos más cortos), floored por la animación de
salida vigente. No toca movimientos, strikes, undo ni progreso.
_Avoid_: pista, ayuda, auto-play, truco.

### Cuenta y ranking

**Session** (Sesión):
Sesión iniciada **persistente**: el `Token` JWT se almacena y se restaura al abrir la app;
no se vuelve a pedir login.
_Avoid_: login como estado, auth-state.

**Leaderboard** (Ranking):
Tabla de mejores `Score` por nivel; el cliente la **lee** y la muestra.

**Leaderboard general** (Ranking de jugadores):
Ranking global de jugadores por **total de puntos** (suma del mejor score por nivel de
**campaña** — temáticos y `GeneratedBoard` no suman), con **total de estrellas** como dato
visible y desempate: el espejo competitivo de los totales del panel de cuenta. Incluye la
posición propia aunque quede fuera del top. Accesible desde el menú principal. Solo refleja
partidas enviadas: una victoria offline cuenta en el progreso local pero no en el ranking
(limitación aceptada 2026-07-16; cola de reenvío = TODO futuro).
_Avoid_: ranking de actividad, suma de todas las runs.

### Producción de niveles

**Candidato (de nivel)**:
Tablero soluble generado con seed fija y exportado como JSON arrow-path, identificado de
forma trazable por su tier y seed (`cand-t3-s302`). Es insumo de la Curación; **no** es un
nivel jugable servido hasta ser curado y congelado en la API.
_Avoid_: nivel provisional, nivel random, borrador jugable.

**Curación**:
Selección manual de 15 Candidatos (3 por Tier) que se congelan como los niveles oficiales
que sirve la API. El orden y `timeLimitSec` los decide la curación, no el generador.
_Avoid_: generación, sorteo, autogenerado.

**Tier (de dificultad)**:
Cada uno de los 5 escalones de la rampa (dimensiones, cantidad de flechas y longitud máxima
de camino crecientes) en que se agrupan Candidatos y niveles curados.
_Avoid_: mundo, capítulo.

**Rampa (de dificultad)**:
La curva de producción que asigna a cada tier sus parámetros objetivo: dimensiones,
densidad de flechas (fracción de celdas ocupadas), longitud máxima de camino y límite de
tiempo derivado del área del tablero. Los saltos entre tiers no son proporcionales; la
campaña v1 remata en un tablero 50×50. Es insumo de la producción de Candidatos, no un
concepto de runtime: el jugador ve niveles, no la Rampa.
_Avoid_: curva implícita en los fixtures, blueprint, configuración del generador.

**Máscara (de figura)**:
Partición de las celdas del tablero en regiones de color, derivada de una **imagen de
referencia** aportada al producir un Nivel temático. Restricción de producción: cada flecha
se confina a una sola región (una flecha = un color; sale entera). La máscara no viaja en el
wire — solo sus consecuencias (las Instrucciones de pintado).
_Avoid_: plantilla, stencil, sprite.

### Vocabulario retirado (no usar)

`ICell`, `WallCell`, `EmptyCell`, `ExitCell`, `CellType`, `CellFactory`, grilla de celdas,
"rotar flecha". El modelo de grilla fue retirado (ver `docs/adr/0001`).

## Glosario

- **Espacio hexagonal (HexSpace):** malla hexagonal flat-top de radio `R`
  (ADR-0007 D1), subclase de `BoardSpace` en Dart puro. Coordenadas axiales
  `(q, r)` mapeadas a `Position` con `col = q + R`, `row = r + R`. Publica 6
  direcciones (`up`, `down` y las 4 diagonales; nunca `left`/`right`),
  `cellCount = 3R²+3R+1` y una caja envolvente `(2R+1)²`. Su gemelo
  `HexMaskedSpace` restringe a un subconjunto de celdas activas (silueta), donde
  toda celda inactiva es frontera de salida.
