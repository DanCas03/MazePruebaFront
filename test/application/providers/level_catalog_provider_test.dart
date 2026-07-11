import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/providers/level_catalog_provider.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';

import 'level_catalog_provider_test.mocks.dart';

@GenerateMocks([ILevelRepository, ILoggerService])
/// Ids del Catálogo en orden de juego (fixture compartida entre casos).
final ids = [LevelId('level-01'), LevelId('level-02')];

/// Nivel mínimo válido (>= 1 flecha) para stubear `getLevel` durante el prefetch.
Level _level() => Level(
      id: LevelId('level-01'),
      board: ArrowBoard(
        arrows: [
          Arrow(
            id: ArrowId('a'),
            cells: [Position(row: 0, col: 0), Position(row: 0, col: 1)],
            headDirection: Direction.right,
          ),
        ],
        cols: 4,
        rows: 4,
      ),
    );

/// Contenedor con `levelCatalogProvider` sobreescrito por el notifier bajo
/// prueba, componiendo los mocks (DIP). Se autodesecha al terminar el test.
ProviderContainer _container(
    MockILevelRepository repo, MockILoggerService logger) {
  final c = ProviderContainer(overrides: [
    levelCatalogProvider.overrideWith(() => LevelCatalogNotifier(repo, logger)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('should_load_ids_and_prefetch_every_level_when_catalog_ok', () async {
    // Arrange
    final repo = MockILevelRepository();
    final logger = MockILoggerService();
    final level = _level();
    when(repo.listLevelIds()).thenAnswer((_) async => Right(ids));
    when(repo.getLevel(any)).thenAnswer((_) async => Right(level));
    final c = _container(repo, logger);

    // Act
    final result = await c.read(levelCatalogProvider.future);

    // Assert — el catálogo carga; tras drenar la cola, el prefetch (disparado con
    // `unawaited` DESPUÉS de resolver el future) corrió por cada id.
    expect(result, ids);
    await pumpEventQueue();
    verify(repo.getLevel(LevelId('level-01'))).called(1);
    verify(repo.getLevel(LevelId('level-02'))).called(1);
  });

  test('should_expose_async_error_when_list_fails', () async {
    // Arrange
    final repo = MockILevelRepository();
    final logger = MockILoggerService();
    when(repo.listLevelIds())
        .thenAnswer((_) async => Left(const LevelUnavailable()));
    final c = _container(repo, logger);

    // Act + Assert — el future propaga el fallo y el estado queda en AsyncError.
    await expectLater(
      c.read(levelCatalogProvider.future),
      throwsA(isA<LevelUnavailable>()),
    );
    final state = c.read(levelCatalogProvider);
    expect(state, isA<AsyncError>());
    expect(state.error, isA<LevelUnavailable>());
  });

  test('should_load_ids_and_warn_when_a_prefetch_fails', () async {
    // Arrange — un `getLevel` falla y el otro va bien.
    final repo = MockILevelRepository();
    final logger = MockILoggerService();
    final level = _level();
    when(repo.listLevelIds()).thenAnswer((_) async => Right(ids));
    when(repo.getLevel(LevelId('level-01')))
        .thenAnswer((_) async => Left(const LevelUnavailable()));
    when(repo.getLevel(LevelId('level-02')))
        .thenAnswer((_) async => Right(level));
    final c = _container(repo, logger);

    // Act
    final result = await c.read(levelCatalogProvider.future);

    // Assert — un prefetch fallido NO rompe la carga; se emite exactamente 1 warn.
    expect(result, ids);
    await pumpEventQueue();
    verify(logger.warn(any, any)).called(1);
  });

  test('should_recover_to_data_when_refresh_after_error', () async {
    // Arrange — el primer intento falla ⇒ estado en error.
    final repo = MockILevelRepository();
    final logger = MockILoggerService();
    final level = _level();
    when(repo.listLevelIds())
        .thenAnswer((_) async => Left(const LevelUnavailable()));
    final c = _container(repo, logger);
    await expectLater(
      c.read(levelCatalogProvider.future),
      throwsA(isA<LevelUnavailable>()),
    );
    expect(c.read(levelCatalogProvider), isA<AsyncError>());

    // Act — el back se recupera y la UI reintenta con `refresh()`.
    when(repo.listLevelIds()).thenAnswer((_) async => Right(ids));
    when(repo.getLevel(any)).thenAnswer((_) async => Right(level));
    c.read(levelCatalogProvider.notifier).refresh();
    final result = await c.read(levelCatalogProvider.future);
    await pumpEventQueue();

    // Assert — el estado ahora lleva los ids.
    expect(result, ids);
    expect(c.read(levelCatalogProvider).valueOrNull, ids);
  });
}
