import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/game_controller.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_exception.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/board_widget.dart';
import 'package:flutter_arrow_maze/presentation/game/widgets/arrow_widget.dart';

import 'board_widget_test.mocks.dart';

// Genera mocks de ILevelRepository y RemoveArrowUseCase.
// El .mocks.dart co-localizado se genera con:
//   dart run build_runner build --delete-conflicting-outputs
@GenerateMocks([ILevelRepository, RemoveArrowUseCase])

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Crea una flecha horizontal de longitud 2 en la fila 0, columna [col].
/// Ocupa las celdas (row:0, col) y (row:0, col+1).
Arrow _arrow(String id, int col) => Arrow.straight(
      id: ArrowId(id),
      tail: Position(row: 0, col: col),
      direction: Direction.right,
      length: 2,
    );

/// Tablero 4×4 con dos flechas:
///   arrow-0: celdas (0,0) y (0,1)
///   arrow-2: celdas (0,2) y (0,3)
ArrowBoard _board() => ArrowBoard(
      arrows: [_arrow('arrow-0', 0), _arrow('arrow-2', 2)],
      cols: 4,
      rows: 4,
    );

/// Monta un [ProviderContainer] con el board listo y el widget árbol
/// de 400×400 que contiene [BoardWidget].
///
/// Con cell = 400/4 = 100:
///   - arrow-0 ocupa los píxeles x ∈ [0,200], y ∈ [0,100]
///   - arrow-2 ocupa los píxeles x ∈ [200,400], y ∈ [0,100]
///   - Las filas 1-3 no tienen flechas.
Future<ProviderContainer> _ready(
  WidgetTester tester,
  MockILevelRepository repo,
  MockRemoveArrowUseCase uc,
) async {
  // Configurar el repo remoto: getLevel → Right(Level con _board()).
  when(repo.getLevel(any)).thenAnswer(
      (_) async => Right(Level(id: LevelId('1'), board: _board())));

  final container = ProviderContainer(overrides: [
    gameControllerProvider.overrideWith(
      () => GameController(repo, uc, CommandInvoker()),
    ),
  ]);
  addTearDown(container.dispose);

  // Disparar loadLevel para que el estado pase a GamePlaying.
  await container.read(gameControllerProvider.notifier).loadLevel(LevelId('1'));

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 400, child: BoardWidget()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── Test conservado de la versión anterior ───────────────────────────────
  // BoardWidget muestra SizedBox.shrink() cuando aún no hay GamePlaying.
  testWidgets('renders nothing while not playing', (tester) async {
    // Arrange — container sin loadLevel → estado GameLoading
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();

    final container = ProviderContainer(overrides: [
      gameControllerProvider.overrideWith(
        () => GameController(repo, uc, CommandInvoker()),
      ),
    ]);
    addTearDown(container.dispose);

    // Act
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 400, child: BoardWidget()),
        ),
      ),
    ));

    // Assert — GameLoading: no se renderizan flechas
    expect(find.byType(ArrowWidget), findsNothing);
  });

  // ─── Regresión del bug de hit-testing ────────────────────────────────────
  // BUG: con el BoardWidget antiguo las flechas se apilaban sin Positioned y
  // sin hit-testing por celda; un toque no enrutaba a la flecha correcta.
  // FIX: el nuevo BoardWidget usa un GestureDetector + arrowAt(Position) para
  // resolver la flecha tocada a partir de las coordenadas del toque.
  testWidgets('un toque enruta a la flecha de ESA celda (fix del bug)', (tester) async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    // El use case devuelve Left para no mutar el board y mantener el estado estable.
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('bloqueada en test')));

    await _ready(tester, repo, uc);

    // Act — tocar la celda (row:0, col:2), centro ≈ (250, 50) con cell=100.
    // Esa celda pertenece a arrow-2 (cols 2-3), NO a arrow-0 (cols 0-1).
    await tester.tapAt(const Offset(250, 50));
    await tester.pump();

    // Assert — se llama con arrow-2, nunca con arrow-0.
    // Regla mockito: si un arg es matcher, todos deben serlo.
    verify(uc.execute(any, argThat(equals(const ArrowId('arrow-2'))))).called(1);
    verifyNever(uc.execute(any, argThat(equals(const ArrowId('arrow-0')))));
  });

  testWidgets('tocar una celda vacía no dispara ningún execute', (tester) async {
    // Arrange
    final repo = MockILevelRepository();
    final uc = MockRemoveArrowUseCase();
    when(uc.execute(any, any))
        .thenReturn(Left(InvalidMoveException('bloqueada en test')));

    await _ready(tester, repo, uc);

    // Act — celda (row:2, col:1) → Offset(150, 250): no hay flecha allí.
    await tester.tapAt(const Offset(150, 250));
    await tester.pump();

    // Assert — ningún execute fue llamado
    verifyNever(uc.execute(any, any));
  });
}
