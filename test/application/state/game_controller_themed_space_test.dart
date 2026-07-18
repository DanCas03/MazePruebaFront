import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/application/state/game_state.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/solution_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_solution_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/services/i_ticker.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/board_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/hex_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/masked_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'game_controller_test.mocks.dart';
import '../../support/arrow_fixtures.dart';

/// Silueta temática de prueba en la caja 4×4, repartida en DOS regiones (rol →
/// celdas) para que el montaje tenga que consumir la UNIÓN y no una sola:
///   'fill': (0,0) (0,1) (1,1)     'eye': (2,2) (2,3)
/// Unión = 5 celdas de las 16 de la caja ⇒ un MaskedSpace distinguible del
/// RectSpace(4,4) del wire. Incluye (1,1), celda de silueta SIN flecha: la
/// figura es la forma, no el rastro de las flechas.
Map<String, Set<Position>> _silhouette() => {
      'fill': {
        Position(row: 0, col: 0),
        Position(row: 0, col: 1),
        Position(row: 1, col: 1),
      },
      'eye': {
        Position(row: 2, col: 2),
        Position(row: 2, col: 3),
      },
    };

Set<Position> _union() => {
      Position(row: 0, col: 0),
      Position(row: 0, col: 1),
      Position(row: 1, col: 1),
      Position(row: 2, col: 2),
      Position(row: 2, col: 3),
    };

/// Tablero 4×4 del wire (espacio RECTANGULAR: el back manda la caja) con dos
/// flechas contenidas en la silueta.
///   arrow-0: (0,0)-(0,1)   arrow-2: (2,2)-(2,3)
ArrowBoard _board() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('arrow-0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
        straightArrow(
          id: const ArrowId('arrow-2'),
          tail: Position(row: 2, col: 2),
          direction: Direction.right,
          length: 2,
        ),
      ],
      space: RectSpace(4, 4),
    );

/// Tablero 4×4 con UNA sola flecha (al quitarla se gana) dentro de la silueta.
ArrowBoard _oneArrowBoard() => ArrowBoard(
      arrows: [
        straightArrow(
          id: const ArrowId('arrow-0'),
          tail: Position(row: 0, col: 0),
          direction: Direction.right,
          length: 2,
        ),
      ],
      space: RectSpace(4, 4),
    );

/// Silueta HEX R=2 (caja 5×5, centro (2,2)): dos celdas contiguas dentro del
/// hexágono. Unión = 2 de las 19 celdas ⇒ HexMaskedSpace distinguible de HexSpace(2).
Map<String, Set<Position>> _hexSilhouette() => {
      'fill': {Position(row: 2, col: 2), Position(row: 2, col: 3)},
    };

Set<Position> _hexUnion() =>
    {Position(row: 2, col: 2), Position(row: 2, col: 3)};

/// Tablero hex R=2 con UNA flecha diagonal (downRight, válida en hex) contenida
/// en la silueta. Se construye con Arrow directo: `straightArrow` usa deltas
/// rect y no aplica a la aritmética hexagonal.
ArrowBoard _hexBoard() => ArrowBoard(
      arrows: [
        Arrow(
          id: const ArrowId('h0'),
          headDirection: Direction.downRight,
          cells: [Position(row: 2, col: 2), Position(row: 2, col: 3)],
        ),
      ],
      space: const HexSpace(2),
    );

void _stubLevel(
  MockILevelRepository repo,
  ArrowBoard board, {
  Map<String, String>? palette,
  Map<String, Set<Position>>? silhouette,
}) =>
    when(repo.getLevel(any)).thenAnswer((_) async => Right(Level(
          id: LevelId('1'),
          board: board,
          palette: palette,
          silhouette: silhouette,
        )));

ProviderContainer _container(MockILevelRepository repo, MockRemoveArrowUseCase uc) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider
        .overrideWith(() => GameController(repo, uc, CommandInvoker())),
  ]);
  addTearDown(c.dispose);
  return c;
}

/// Repo de solución con orden de vaciado prefijado: la demo de pista solo
/// necesita la lista de ids del back para reproducirla verbatim.
class _FakeSolutionRepo implements ISolutionRepository {
  final List<ArrowId> order;
  _FakeSolutionRepo(this.order);

  @override
  Future<Either<SolutionFailure, List<ArrowId>>> getSolution(LevelId id) async =>
      Right(order);
}

/// Contenedor con repo de solución falso y paso de demo instantáneo, para
/// ejercer el tercer punto de montaje: la pista auto-resolutora.
ProviderContainer _hintContainer(
  MockILevelRepository repo,
  MockRemoveArrowUseCase uc,
  _FakeSolutionRepo solutionRepo,
) {
  final c = ProviderContainer(overrides: [
    gameControllerProvider.overrideWith(() => GameController(
          repo,
          uc,
          CommandInvoker(),
          const NullTicker(),
          solutionRepo,
          (_) => Duration.zero,
        )),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('un nivel con silueta se monta sobre el MaskedSpace de su figura',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(),
        palette: const {'fill': '#ff0000'}, silhouette: _silhouette());
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — la silueta ES el tablero (#118): fuera de ella no hay espacio.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, isA<MaskedSpace>());
    expect((state.board.space as MaskedSpace).activeCells, _union());
    expect(state.board.space, MaskedSpace(4, 4, activeCells: _union()));
    expect(state.board.arrows.length, 2); // mismas flechas, otro espacio
  });

  test('el MaskedSpace montado veta las celdas fuera de la silueta', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(),
        palette: const {'fill': '#ff0000'}, silhouette: _silhouette());
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — (1,1) es silueta; (3,3) está en la caja pero NO en la figura.
    final space = (c.read(gameControllerProvider).valueOrNull as GamePlaying)
        .board
        .space;
    expect(space.contains(Position(row: 1, col: 1)), isTrue);
    expect(space.contains(Position(row: 3, col: 3)), isFalse);
    expect(space.cellCount, 5); // solo la figura es superficie
  });

  test('un nivel de campaña (sin silueta) conserva el RectSpace del wire',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board()); // sin palette ni silhouette
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — la campaña no se enmascara: mismo espacio, idéntico al wire.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, RectSpace(4, 4));
    expect(state.board.space, isNot(isA<MaskedSpace>()));
    expect(state.board, _board());
  });

  test('un nivel temático SIN silueta conserva el RectSpace del wire', () async {
    // Arrange — la señal de montaje es la silueta, no la paleta: un temático
    // que aún no la declare sigue jugándose sobre su caja.
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(), palette: const {'fill': '#ff0000'});
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, RectSpace(4, 4));
    expect(state.board.space, isNot(isA<MaskedSpace>()));
  });

  test('reiniciar un nivel con silueta re-monta el MISMO MaskedSpace', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(),
        palette: const {'fill': '#00ff00'}, silhouette: _silhouette());
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));

    // Act
    await notifier.restartLevel();

    // Assert — sin refetch, se re-monta la figura, no la caja.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, MaskedSpace(4, 4, activeCells: _union()));
  });

  test('undo desde GameWon reconstruye el tablero sobre el MISMO MaskedSpace',
      () async {
    // Arrange — un solo movimiento limpia el tablero ⇒ GameWon; el undo debe
    // reinsertar la flecha en el espacio con que se MONTÓ el nivel, no en el
    // crudo del wire.
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _oneArrowBoard(),
        palette: const {'fill': '#0000ff'}, silhouette: _silhouette());
    when(uc.execute(any, any)).thenReturn(Right(_oneArrowBoard()));
    final c = _container(repo, uc);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    await notifier.tapArrow(const ArrowId('arrow-0'));
    expect(c.read(gameControllerProvider).valueOrNull, isA<GameWon>());

    // Act
    await notifier.undoMove();

    // Assert
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, MaskedSpace(4, 4, activeCells: _union()));
    expect(state.board.arrows.length, 1); // la flecha vuelve al tablero
  });

  test('la demo de pista se reproduce sobre el MISMO MaskedSpace', () async {
    // Arrange — temático ⇒ siempre elegible para la pista (por palette).
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _board(),
        palette: const {'fill': '#ff0000'}, silhouette: _silhouette());
    final solutionRepo = _FakeSolutionRepo(
        const [ArrowId('arrow-0'), ArrowId('arrow-2')]);
    final c = _hintContainer(repo, uc, solutionRepo);
    final notifier = c.read(gameControllerProvider.notifier);
    await notifier.loadLevel(LevelId('1'));
    final demoSpaces = <BoardSpace>[];
    c.listen(gameControllerProvider, (_, next) {
      final s = next.valueOrNull;
      if (s is GamePlaying && s.hintPlaying) demoSpaces.add(s.board.space);
    });

    // Act
    await notifier.playHint();

    // Assert — cada fotograma de la demo se dibuja sobre la figura, nunca
    // sobre la caja cruda del wire.
    expect(demoSpaces, isNotEmpty);
    expect(demoSpaces, everyElement(MaskedSpace(4, 4, activeCells: _union())));
  });

  test('un nivel temático hexagonal se monta sobre HexMaskedSpace', () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _hexBoard(),
        palette: const {'fill': '#ff0000'}, silhouette: _hexSilhouette());
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — el hex+silueta se monta sobre su gemelo enmascarado, no sobre
    // MaskedSpace rectangular ni sobre el HexSpace crudo.
    final state = c.read(gameControllerProvider).valueOrNull as GamePlaying;
    expect(state.board.space, isA<HexMaskedSpace>());
    expect(state.board.space, HexMaskedSpace(2, activeCells: _hexUnion()));
    expect((state.board.space as HexMaskedSpace).activeCells, _hexUnion());
  });

  test(
      'el HexMaskedSpace montado veta las celdas hex fuera de la silueta y la máscara es la frontera del exitLane',
      () async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    _stubLevel(repo, _hexBoard(),
        palette: const {'fill': '#ff0000'}, silhouette: _hexSilhouette());
    final c = _container(repo, uc);

    // Act
    await c.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

    // Assert — (2,2) es silueta; (2,4) está en el hexágono R=2 pero NO en la
    // figura ⇒ frontera. El exitLane desde (2,3) hacia downRight se detiene en
    // la máscara: la figura es el borde por el que la flecha sale.
    final space = (c.read(gameControllerProvider).valueOrNull as GamePlaying)
        .board
        .space;
    expect(space.contains(Position(row: 2, col: 2)), isTrue);
    expect(space.contains(Position(row: 2, col: 4)), isFalse);
    expect(space.cellCount, 2);
    expect(space.exitLane(Position(row: 2, col: 3), Direction.downRight),
        isEmpty);
  });
}
