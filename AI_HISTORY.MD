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
