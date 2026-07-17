import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/failures/solution_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_solution_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/catalog_entry.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_section.dart';
import 'package:flutter_arrow_maze/domain/game_core/services/i_ticker.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

// ── Dobles de test hechos a mano (sin build_runner) ──────────────────────────

/// Repo de niveles que siempre resuelve el [Level] inyectado. La pista no
/// depende de la red de niveles; basta un stub estable.
class _FakeLevelRepo implements ILevelRepository {
  final Level level;
  _FakeLevelRepo(this.level);

  @override
  Future<Either<LevelFailure, Level>> getLevel(LevelId id) async => Right(level);

  @override
  Future<Either<LevelFailure, List<CatalogEntry>>> listCatalog() async =>
      Right([CatalogEntry(id: level.id, section: LevelSection.campaign)]);
}

/// Repo de solución con respuesta prefijada y contador de llamadas. Permite
/// diferir la respuesta (Completer) para observar el sub-estado de carga.
class _FakeSolutionRepo implements ISolutionRepository {
  Either<SolutionFailure, List<ArrowId>>? response;
  Completer<Either<SolutionFailure, List<ArrowId>>>? deferred;
  int calls = 0;

  _FakeSolutionRepo({this.response, this.deferred});

  @override
  Future<Either<SolutionFailure, List<ArrowId>>> getSolution(LevelId id) {
    calls++;
    if (deferred != null) return deferred!.future;
    return Future.value(response);
  }
}

Arrow _arrow(String id, int col) => straightArrow(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: 2,
    );

/// Tablero 4x4 con dos flechas.
ArrowBoard _twoArrowBoard() =>
    ArrowBoard(arrows: [_arrow('a0', 0), _arrow('a2', 2)], space: RectSpace(4, 4));

Level _level(String id) =>
    Level(id: LevelId(id), board: _twoArrowBoard());

/// Contenedor con el controlador compuesto para la pista: repos falsos, sin
/// reloj real y paso de demo instantáneo (Duration.zero) para no esperar.
ProviderContainer _container(
  _FakeLevelRepo levelRepo,
  _FakeSolutionRepo solutionRepo,
) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider.overrideWith(
      () => GameController(
        levelRepo,
        RemoveArrowUseCase(),
        CommandInvoker(),
        const NullTicker(),
        solutionRepo,
        (_) => Duration.zero,
      ),
    ),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('playHint reproduce la solución y reinicia a un tablero jugable',
      () async {
    // Arrange — nivel elegible (≥ 7); la solución vacía en orden a0, a2.
    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(
      response: Right([const ArrowId('a0'), const ArrowId('a2')]),
    );
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Registra la traza de estados para verificar que la demo ocurrió.
    final playingSeen = <bool>[];
    var sawClearedBoard = false;
    c.listen(gameControllerProvider, (_, next) {
      final s = next.valueOrNull;
      if (s is GamePlaying) {
        playingSeen.add(s.hintPlaying);
        if (s.board.arrows.isEmpty) sawClearedBoard = true;
      }
    });

    // Act
    await notifier.playHint();

    // Assert — se pidió la solución una vez, la demo pasó por hintPlaying y
    // vació el tablero, y al terminar el nivel quedó jugable (2 flechas, 0
    // movimientos, sin carga/reproducción activas).
    expect(solutionRepo.calls, 1);
    expect(playingSeen.contains(true), isTrue, reason: 'hubo reproducción');
    expect(sawClearedBoard, isTrue, reason: 'el tablero se vació en la demo');

    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.hintPlaying, isFalse);
    expect(s.hintLoading, isFalse);
    expect(s.board.arrows.length, 2);
    expect(s.moves.value, 0);
    expect(s.canUndo, isFalse);
  });

  test('playHint marca hintLoading mientras la petición está en tránsito',
      () async {
    // Arrange — la respuesta se difiere para congelar el estado de carga.
    final deferred =
        Completer<Either<SolutionFailure, List<ArrowId>>>();
    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(deferred: deferred);
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act — no se espera: el cuerpo síncrono ya fijó el sub-estado de carga.
    final future = notifier.playHint();
    final loading = c.read(gameControllerProvider).valueOrNull as GamePlaying;

    // Assert — bombilla en carga y tablero intacto.
    expect(loading.hintLoading, isTrue);
    expect(loading.hintPlaying, isFalse);
    expect(loading.board.arrows.length, 2);

    // Cierra la petición para no dejar el future colgado.
    deferred.complete(Right([const ArrowId('a0'), const ArrowId('a2')]));
    await future;
    final done = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(done.hintLoading, isFalse);
  });

  test('playHint conserva la partida y dispara el nonce de error cuando falla',
      () async {
    // Arrange — el back no responde a tiempo (timeout → SolutionUnavailable).
    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(
      response: const Left(SolutionUnavailable()),
    );
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act
    await notifier.playHint();

    // Assert — sigue siendo la MISMA partida (2 flechas, 0 movimientos), sin
    // carga colgada, y el nonce de error subió para que la UI avise.
    expect(solutionRepo.calls, 1);
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.hintLoading, isFalse);
    expect(s.hintPlaying, isFalse);
    expect(s.hintErrorNonce, 1);
    expect(s.board.arrows.length, 2);
    expect(s.moves.value, 0);
  });

  test(
      'playHint funciona en un nivel de campaña que antes era inelegible (< 7, #102)',
      () async {
    // Arrange — nivel 3: bajo el viejo umbral #32, ahora elegible.
    final levelRepo = _FakeLevelRepo(_level('3'));
    final solutionRepo = _FakeSolutionRepo(
      response: Right([const ArrowId('a0'), const ArrowId('a2')]),
    );
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('3'));

    // Act
    await notifier.playHint();

    // Assert — se pidió la solución y la demo corrió normalmente.
    expect(solutionRepo.calls, 1);
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.hintLoading, isFalse);
    expect(s.hintPlaying, isFalse);
    expect(s.board.arrows.length, 2);
  });

  test(
      'playHint deriva el delay entre pasos del largo de la Solución, no de una constante (#102)',
      () async {
    // Arrange — un stepDelayFor espía: registra el conteo con que se invoca en
    // vez de esperar tiempo real, para verificar el WIRING sin depender de
    // relojes de verdad.
    final seenArrowCounts = <int>[];
    Duration spyStepDelay(int arrowCount) {
      seenArrowCounts.add(arrowCount);
      return Duration.zero;
    }

    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(
      response: Right([const ArrowId('a0'), const ArrowId('a2')]),
    );
    final c = ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(
          levelRepo,
          RemoveArrowUseCase(),
          CommandInvoker(),
          const NullTicker(),
          solutionRepo,
          spyStepDelay,
        ),
      ),
    ]);
    addTearDown(c.dispose);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act
    await notifier.playHint();

    // Assert — se invocó UNA vez, con el largo real de la Solución (2
    // flechas) — nunca con una constante ajena al tamaño de la demo. El mismo
    // delay se reutiliza en todos los pasos (no se recalcula por flecha).
    expect(seenArrowCounts, [2]);
  });

  test(
      'la demo del auto-solver expone la duración de salida comprimida en el estado (#102)',
      () async {
    // Arrange — una Solución de 2 flechas: por debajo del piso "chico" de
    // AutoSolvePacing, así que la duración de salida esperada es la estándar
    // (360 ms) — igual sirve para verificar que el campo viaja en el estado.
    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(
      response: Right([const ArrowId('a0'), const ArrowId('a2')]),
    );
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    var sawExitDurationDuringPlayback = false;
    c.listen(gameControllerProvider, (_, next) {
      final s = next.valueOrNull;
      if (s is GamePlaying && s.hintPlaying) {
        expect(s.autoSolveExitDuration, const Duration(milliseconds: 360));
        sawExitDurationDuringPlayback = true;
      }
    });

    // Act
    await notifier.playHint();

    // Assert — se emitió al menos un estado de reproducción con el campo
    // seteado, y al reiniciar (nivel jugable de nuevo) vuelve a null.
    expect(sawExitDurationDuringPlayback, isTrue);
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.autoSolveExitDuration, isNull);
  });

  test('tapArrow se ignora mientras la pista está en carga', () async {
    // Arrange — respuesta diferida: la partida queda en hintLoading.
    final deferred =
        Completer<Either<SolutionFailure, List<ArrowId>>>();
    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(deferred: deferred);
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));
    final future = notifier.playHint();
    expect(
      (c.read(gameControllerProvider).valueOrNull as GamePlaying).hintLoading,
      isTrue,
    );

    // Act — un tap durante la carga no debe mover el tablero ni contar.
    await notifier.tapArrow(const ArrowId('a0'));

    // Assert — tablero intacto, sin salida animada.
    final s = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(s.board.arrows.length, 2);
    expect(s.exitNonce, 0);
    expect(s.moves.value, 0);

    deferred.complete(const Left(SolutionUnavailable()));
    await future;
  });

  test('playHint ignora un segundo clic mientras ya está en curso', () async {
    // Arrange — respuesta diferida para mantener la primera pista en vuelo.
    final deferred =
        Completer<Either<SolutionFailure, List<ArrowId>>>();
    final levelRepo = _FakeLevelRepo(_level('7'));
    final solutionRepo = _FakeSolutionRepo(deferred: deferred);
    final c = _container(levelRepo, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('7'));

    // Act — dos clics seguidos; el segundo cae en el guard anti doble-clic.
    final f1 = notifier.playHint();
    final f2 = notifier.playHint();

    // Assert — la solución se pidió una sola vez.
    expect(solutionRepo.calls, 1);

    deferred.complete(Right([const ArrowId('a0'), const ArrowId('a2')]));
    await Future.wait([f1, f2]);
  });
}
