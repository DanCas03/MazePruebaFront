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
Nadie toca un `Arrow` desde fuera del tablero.
_Avoid_: grid, grilla, matriz de celdas, board de celdas.

**exit path** (carril de salida):
Celdas libres que la cabeza debe recorrer en línea recta hasta el borde para que la flecha
salga. Si todas están libres de otras flechas, la flecha puede salir.
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
Tope de tiempo opcional de un nivel (niveles avanzados); agotarlo → `GameLost`.

### Nivel y progreso

**Level / LevelId**:
Definición de un nivel (dimensiones + flechas) identificada por `LevelId`, **obtenida del
backend**. El cliente no genera los niveles oficiales.
_Avoid_: mapa, stage, pantalla.

**Progress** (Progreso):
Por nivel: completado, mejores estrellas y mejor score. Se guarda local (Hive) y se
sincroniza con el backend.

**Stars** (Estrellas):
1–3 por nivel, según choques y movimientos respecto del óptimo.

**Score** (Puntaje):
Valor numérico = f(tiempo, movimientos sobre óptimo, choques). Define el ranking.

**Solution** (Solución):
El orden de `ArrowId`, producido y servido por el **backend**, cuya remoción en secuencia
vacía el tablero. El cliente la **anima**; nunca deriva el orden (ADR 0002).
_Avoid_: respuesta, walkthrough, camino ganador.

**Hint** (Pista):
Demo **no puntuada** en niveles elegibles (política del cliente): reinicia el nivel y
reproduce la Solución animada. No toca movimientos, strikes, undo ni progreso.
_Avoid_: ayuda, auto-play, truco.

### Cuenta y ranking

**Session** (Sesión):
Sesión iniciada **persistente**: el `Token` JWT se almacena y se restaura al abrir la app;
no se vuelve a pedir login.
_Avoid_: login como estado, auth-state.

**Leaderboard** (Ranking):
Tabla de mejores `Score` por nivel; el cliente la **lee** y la muestra.

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

### Vocabulario retirado (no usar)

`ICell`, `WallCell`, `EmptyCell`, `ExitCell`, `CellType`, `CellFactory`, grilla de celdas,
"rotar flecha". El modelo de grilla fue retirado (ver `docs/adr/0001`).
