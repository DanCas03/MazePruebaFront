import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_arrow_maze/presentation/providers/dependency_providers.dart';
import 'package:flutter_arrow_maze/application/use_cases/sync_progress_use_case.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_remote_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';

class _FakeRemote implements IRemoteProgressRepository {
  @override
  Future<List<LevelProgress>> pull() async => [];
  @override
  Future<List<LevelProgress>> push(List<LevelProgress> progress) async => progress;
}

void main() {
  test('should_compose_SyncProgressUseCase_when_remote_provider_overridden', () {
    // Arrange
    final container = ProviderContainer(overrides: [
      remoteProgressRepositoryProvider.overrideWithValue(_FakeRemote()),
    ]);
    addTearDown(container.dispose);
    // Act
    final useCase = container.read(syncProgressUseCaseProvider);
    // Assert
    expect(useCase, isA<SyncProgressUseCase>());
  });
}
