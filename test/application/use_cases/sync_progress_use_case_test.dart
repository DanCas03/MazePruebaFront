import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/services/progress_reconciler.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/application/use_cases/sync_progress_use_case.dart';

import 'sync_progress_use_case_test.mocks.dart';

@GenerateMocks([
  IRemoteProgressRepository,
  ILevelProgressRepository,
  ILoggerService,
])
void main() {
  late MockIRemoteProgressRepository remote;
  late MockILevelProgressRepository local;
  late MockILoggerService logger;
  late SyncProgressUseCase useCase;

  setUp(() {
    remote = MockIRemoteProgressRepository();
    local = MockILevelProgressRepository();
    logger = MockILoggerService();
    useCase = SyncProgressUseCase(remote, local, ProgressReconciler(), logger);
  });

  test('should_pull_reconcile_push_and_persist_when_syncing', () async {
    // Arrange
    when(remote.pull()).thenAnswer((_) async =>
        [LevelProgress(levelId: LevelId('1'), completed: true, bestScore: 500)]);
    when(local.getAll()).thenAnswer((_) async =>
        [LevelProgress(levelId: LevelId('1'), completed: false, bestScore: 900)]);
    when(remote.push(any)).thenAnswer((inv) async =>
        inv.positionalArguments.first as List<LevelProgress>);
    when(local.upsertAll(any)).thenAnswer((_) async {});

    // Act
    await useCase.execute();

    // Assert — best score gana (900) y se pushea + persiste el merge
    final pushed =
        verify(remote.push(captureAny)).captured.single as List<LevelProgress>;
    expect(pushed.single.bestScore, 900);
    final persisted =
        verify(local.upsertAll(captureAny)).captured.single as List<LevelProgress>;
    expect(persisted.single.bestScore, 900);
  });

  test('should_not_throw_and_log_error_when_network_fails', () async {
    // Arrange
    when(remote.pull()).thenThrow(Exception('network down'));

    // Act
    Future<void> act() => useCase.execute();

    // Assert — el fallo de red no rompe el flujo; se loguea el error
    await expectLater(act(), completes);
    verify(logger.error(any, any, any)).called(1);
    verifyNever(local.upsertAll(any));
  });
}
