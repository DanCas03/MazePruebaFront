# AI History — MazePruebaFront

## Entrada 001 — Phase 0: Eliminación dominio viejo y stubs de compilación

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Crear la rama `feat/main-sprint` y limpiar el dominio anterior (`board`/`player`, `GameController`, `CellWidget`) del proyecto Flutter, reemplazando los archivos que siguen siendo referenciados con stubs mínimos que compilan sin errores.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development)
**Prompt o instrucción proporcionada:** > "Execute Phase 0 of the Main Sprint plan: create feat/main-sprint branch in both repos, remove old game domain from Flutter front, replace six files with compile-only stubs, verify builds, and commit."
**Resultado obtenido:** 
- Eliminados: `lib/domain/board/`, `lib/domain/player/`, `rotate_arrow_use_case.dart`, `check_win_condition_use_case.dart`, `move_player_use_case.dart`, `move_command.dart`, `rotate_command.dart`, `level_repository_impl.dart`, `game_controller.dart`, `cell_widget.dart`.
- Reemplazados con stubs mínimos: `direction.dart`, `position.dart` (con `row`/`col`), `command.dart` (`abstract interface class ICommand`), `command_invoker.dart`, `game_screen.dart`, `board_widget.dart`.
- `flutter analyze`: No issues found.
- `flutter test`: 1/1 passed (widget_test).
**Modificaciones realizadas por el equipo:**

## Entrada 002 — Task 2B.1: Jerarquía de excepciones de dominio (Dart puro)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Crear la jerarquía de excepciones de dominio del front (Clean Mobile Architecture, capa `domain` en Dart puro sin Flutter/Hive/Riverpod) que usarán los Value Objects, entidades y casos de uso para señalar violaciones de invariantes y recursos no encontrados.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.1 (Domain: Excepciones Dart puro): clase base abstracta `DomainException implements Exception` con `message` y `toString()`, más seis subclases (`InvalidPositionException`, `InvalidArrowException`, `InvalidLevelIdException`, `InvalidMoveCountException`, `ArrowNotFoundException`, `LevelNotFoundException`) bajo `lib/domain/core/exceptions/`, siguiendo TDD (RED/GREEN) con tests AAA."
**Resultado obtenido:**
- Creada clase base abstracta `DomainException implements Exception` en `lib/domain/core/exceptions/domain_exception.dart` con campo `message` const y `toString() => '$runtimeType: $message'`.
- Creadas seis subclases concretas (`InvalidPositionException`, `InvalidArrowException`, `InvalidLevelIdException`, `InvalidMoveCountException`, `ArrowNotFoundException`, `LevelNotFoundException`), cada una con constructor const reenviando el mensaje vía `super.message`.
- Añadido `test/domain/core/exceptions/domain_exception_test.dart` (AAA): verifica `isA<Exception>`/`isA<DomainException>`, propagación del mensaje y formato de `toString()` por cada subclase.
- TDD: RED confirmado (los tests no compilaban sin las clases), luego GREEN (9/9 del archivo, 10/10 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 003 — Task 2B.2: Value Objects de dominio (Equatable, Dart puro)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar los Value Objects inmutables del dominio del front (Clean Mobile Architecture, capa `domain` en Dart puro): `Position`, `Direction`, `ArrowId`, `ArrowLength`, `LevelId`, `MoveCount` y `Email`. Cada VO valida sus invariantes en el constructor y deriva su igualdad de `Equatable.props`. Se aplica el override de taxonomía D1 (bounded contexts) sobre las rutas literales del plan.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.2 (Domain: Value Objects) siguiendo TDD (RED/GREEN) con tests AAA: crear los VOs inmutables con Equatable; `MoveCount.increment()` retorna nueva instancia; respetar el override de layout (arrow_id/arrow_length en `arrows/value_objects/`, level_id en `board/value_objects/`, position/direction/move_count en `game_core/value_objects/`, email en `auth/value_objects/`)."
**Resultado obtenido:**
- Reemplazado el stub `lib/domain/game_core/value_objects/position.dart` por el VO Equatable completo (`row`/`col`, valida `>= 0` → `InvalidPositionException`).
- `direction.dart` conservado (enum `up|down|left|right`).
- Creados `lib/domain/game_core/value_objects/move_count.dart` (`const`, `increment()` → nueva instancia con `value+1`), `lib/domain/arrows/value_objects/arrow_id.dart` (`const`, no valida), `lib/domain/arrows/value_objects/arrow_length.dart` (valida `>= 1` → `InvalidArrowException`), `lib/domain/board/value_objects/level_id.dart` (valida no-vacío → `InvalidLevelIdException`) y `lib/domain/auth/value_objects/email.dart` (regex → `ArgumentError`, igualdad case-insensitive).
- Override de layout D1 aplicado: `arrow_id`/`arrow_length` en contexto `arrows/`, `level_id` en contexto `board/`; imports relativos a `core/exceptions/` corregidos a la ubicación overridden. Imports de test usan el nombre real del paquete `flutter_arrow_maze`.
- Tests AAA (`position_test.dart`, `arrow_length_test.dart`, `move_count_test.dart`). TDD: RED confirmado (stub sin params nombrados y archivos inexistentes), luego GREEN (10/10 del directorio de VOs, 20/20 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 004 — Task 2B.3: Entidad Arrow y Aggregate Root ArrowBoard (Dart puro)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar la entidad `Arrow` y el Aggregate Root `ArrowBoard` del dominio del front (Clean Mobile Architecture, capa `domain` en Dart puro). `Arrow` modela una flecha multi-celda con `id`, `tail`, `direction`, `length` y propiedades calculadas `head`, `cells` y `exitPath(cols, rows)`. `ArrowBoard` es el único punto de acceso al estado del tablero: expone `canExit(ArrowId)`, `removeArrow(ArrowId)` (retorna un nuevo board inmutable) e `isCleared`; nadie accede a `Arrow` directamente, todo pasa por el agregado.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.3 (Domain: Arrow entity + ArrowBoard Aggregate Root) siguiendo TDD (RED/GREEN) con tests AAA: `Arrow` con `head`/`cells`/`exitPath` por dirección; `ArrowBoard` con `canExit`/`removeArrow`/`isCleared` y detección de bloqueo por celdas ocupadas; respetar el override de layout D1 (arrow_id/arrow_length en `arrows/value_objects/`)."
**Resultado obtenido:**
- Creado `lib/domain/arrows/entities/arrow.dart`: entidad `Equatable` inmutable. `head` calcula la última celda según `direction`; `cells` genera todas las posiciones ocupadas en orden; `exitPath(cols, rows)` devuelve las celdas libres que la flecha debe recorrer hasta el borde (vacío si la cabeza ya está en el borde).
- Creado `lib/domain/arrows/entities/arrow_board.dart`: Aggregate Root `Equatable`. `canExit` comprueba que ninguna celda de `exitPath` esté en el conjunto de celdas ocupadas por las demás flechas; `removeArrow` retorna un `ArrowBoard` nuevo sin esa flecha; `isCleared` es `true` cuando no quedan flechas. Comentario inline documenta el patrón Aggregate Root.
- Override de layout D1 aplicado: imports de `arrow_id`/`arrow_length` resueltos a `arrows/value_objects/` (no a `game_core/value_objects/` como en el literal del plan); `position`/`direction` siguen en `game_core/value_objects/`. Imports de test usan el nombre real del paquete `flutter_arrow_maze` (el plan literal usaba un placeholder `maze_prueba_front`).
- Tests AAA (`test/domain/entities/arrow_test.dart` 4 casos, `test/domain/entities/arrow_board_test.dart` 5 casos). TDD: RED confirmado (entidades inexistentes), luego GREEN (9/9 del directorio de entidades, 29/29 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 005 — Task 2B.4: Puertos de dominio (ILevelProgressRepository, ILevelGenerator)

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Definir los puertos (interfaces Dart puro) que la infraestructura implementará en tareas posteriores: `ILevelProgressRepository` (persistencia de progreso/finalización por nivel) e `ILevelGenerator` (generación de tableros solucionables). Aplican la Regla de Dependencia (DIP): el dominio depende solo de abstracciones; las implementaciones concretas (Hive, generador DAG) se inyectan desde fuera.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.4 (Domain: Ports) siguiendo TDD (RED/GREEN) con tests AAA. Crear `ILevelProgressRepository` con getProgress/saveProgress/markCompleted/isCompleted e `ILevelGenerator` con generate(cols, rows, arrowCount). Respetar el override de layout D1 (level_id en `board/value_objects/`, move_count en `game_core/value_objects/`)."
**Resultado obtenido:**
- Creado `lib/domain/board/repositories/i_level_progress_repository.dart`: `abstract interface class ILevelProgressRepository` con `getProgress(LevelId) -> Future<MoveCount?>`, `saveProgress(LevelId, MoveCount)`, `markCompleted(LevelId)`, `isCompleted(LevelId) -> Future<bool>`.
- Creado `lib/domain/arrows/services/i_level_generator.dart`: `abstract interface class ILevelGenerator` con `generate({required int cols, required int rows, required int arrowCount}) -> ArrowBoard` (tablero solucionable por construcción DAG).
- Override de layout D1 aplicado: el import de `LevelId` se resolvió a `board/value_objects/level_id.dart` (no a `game_core/value_objects/` como en el literal del plan); `MoveCount` permanece en `game_core/value_objects/move_count.dart`.
- Tests de contrato AAA con fakes/stubs en memoria que implementan cada puerto (verifican sustituibilidad LSP y la superficie de la interfaz): `test/domain/repositories/i_level_progress_repository_test.dart` (4 casos), `test/domain/services/i_level_generator_test.dart` (2 casos). TDD: RED confirmado (puertos inexistentes -> fallo de compilación), luego GREEN (6/6 de los nuevos tests, 35/35 suite completa). `flutter analyze`: No issues found. Dominio Dart puro, cero imports de Flutter/Hive/Riverpod.
**Modificaciones realizadas por el equipo:**

## Entrada 006 — Task 2B.5: Application — RemoveArrowUseCase

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Implementar el caso de uso de aplicación `RemoveArrowUseCase`, que orquesta la mecánica central del juego: dada una `ArrowBoard` y un `ArrowId`, devuelve `Right(newBoard)` si la flecha puede salir (camino libre hasta el borde) o `Left(DomainException)` si está bloqueada. Actúa como fachada de aplicación sobre la lógica del Aggregate Root (`canExit`/`removeArrow`), sin filtrar reglas de dominio a la presentación.
**Herramienta de IA utilizada:** Claude Code (subagent-driven-development, opus)
**Prompt o instrucción proporcionada:** > "Implementar Task 2B.5 (Application: RemoveArrowUseCase) siguiendo TDD (RED/GREEN) con tests AAA. `execute(ArrowBoard, ArrowId)` devuelve `Either<DomainException, ArrowBoard>`: Right si `canExit`, Left (`ArrowNotFoundException`) si bloqueada. Respetar el override de layout D1 (arrow_id en `arrows/value_objects/`)."
**Resultado obtenido:**
- Creado `lib/application/use_cases/remove_arrow_use_case.dart`: clase `RemoveArrowUseCase` con `Either<DomainException, ArrowBoard> execute(ArrowBoard board, ArrowId arrowId)`. Si `!board.canExit(arrowId)` -> `Left(ArrowNotFoundException(...))`; en otro caso `Right(board.removeArrow(arrowId))`. Usa `dartz.Either` para el flujo funcional de error sin excepciones lanzadas.
- Override de layout D1 aplicado: el import de `ArrowId` se resolvió a `arrows/value_objects/arrow_id.dart` (no a `game_core/value_objects/` como en el literal del plan).
- Adaptación al repo: el prefijo de paquete del plan (`maze_prueba_front`) se corrigió al nombre real del paquete (`flutter_arrow_maze`) en los imports del test.
- Test AAA: `test/application/use_cases/remove_arrow_use_case_test.dart` (2 casos: salida exitosa -> Right con tablero limpio; flecha bloqueada por otra flecha en el camino de salida -> Left<DomainException>). TDD: RED confirmado (caso de uso inexistente -> fallo de compilación), luego GREEN (2/2 de los nuevos tests, 37/37 suite completa). `flutter analyze`: No issues found.
**Modificaciones realizadas por el equipo:**

## Entrada 007 - Task 2B.5 (fix): distinguir id ausente de salida bloqueada

**Fecha:** 2026-06-17
**Tarea o problema abordado:** Hallazgo de revision (important) sobre `RemoveArrowUseCase`: `ArrowBoard.canExit` devuelve `false` por dos condiciones distintas (id inexistente vs. flecha presente pero camino bloqueado). El codigo original colapsaba ambas en `Left(ArrowNotFoundException('... path is blocked'))`, contradictorio en los dos casos (tipo "not found" para el caso comun de juego; mensaje "path is blocked" para un id realmente ausente). La presentacion no podia distinguir un error de programacion de un movimiento invalido legitimo. Es un defecto inducido por el literal del plan (lineas 2544-2546), marcado como origen para enmendar el plan.
**Herramienta de IA utilizada:** Claude Code (opus)
**Prompt o instruccion proporcionada:** > "Corregir hallazgos de revision de 2B.5: distinguir id ausente (ArrowNotFoundException) de flecha bloqueada (InvalidMoveException); reejecutar tests; commit fix(...)."
**Resultado obtenido:**
- Anadido `bool contains(ArrowId)` al Aggregate Root `ArrowBoard` (la pertenencia es conocimiento del AR; antes solo existia el privado `_findById`). Permite al caso de uso desambiguar sin iterar la lista de arrows fuera del agregado.
- Creada excepcion dedicada `lib/domain/core/exceptions/invalid_move_exception.dart` (`InvalidMoveException`) para el resultado legitimo "presente pero bloqueado", distinta de `InvalidMoveCountException` (validacion de conteo) y de `ArrowNotFoundException` (error de programacion).
- `RemoveArrowUseCase.execute` ahora ramifica por pertenencia primero: id ausente -> `Left(ArrowNotFoundException('Arrow <id> not found on the board'))`; presente pero bloqueada -> `Left(InvalidMoveException('Arrow <id> cannot exit - path is blocked'))`; camino libre -> `Right(board.removeArrow(id))`. Tipo y mensaje coherentes en cada rama.
- Tests: el caso bloqueado asevera `isA<InvalidMoveException>()`; nuevo caso para id ausente asevera `isA<ArrowNotFoundException>()`; dos tests para `contains`; `InvalidMoveException` anadida a la jerarquia de excepciones. GREEN: 20/20 del area afectada, 41/41 suite completa, salida pristina.
**Modificaciones realizadas por el equipo:**