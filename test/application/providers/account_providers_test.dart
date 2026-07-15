import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/providers/account_providers.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/core/di/dependency_providers.dart';
import 'package:flutter_arrow_maze/domain/auth/entities/user_profile.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/username.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_progress_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_progress.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';

/// Fake del puerto de auth: `me()` devuelve el Either configurado; el resto
/// no se ejercita en estos providers.
class _FakeAuthRepo implements IAuthRepository {
  final Either<AuthFailure, UserProfile> _meResult;
  _FakeAuthRepo(this._meResult);

  @override
  Future<Either<AuthFailure, UserProfile>> me() async => _meResult;

  @override
  Future<Either<AuthFailure, AuthToken>> login(Email email, String password) =>
      throw UnimplementedError();
  @override
  Future<Either<AuthFailure, AuthToken>> register(
          Email email, String username, String password) =>
      throw UnimplementedError();
}

/// Fake del repo local de progreso: `getAll()` devuelve la lista configurada.
class _FakeProgressRepo implements ILevelProgressRepository {
  final List<LevelProgress> _all;
  _FakeProgressRepo(this._all);

  @override
  Future<List<LevelProgress>> getAll() async => _all;

  @override
  Future<void> upsertAll(List<LevelProgress> progress) async {}
  @override
  Future<MoveCount?> getProgress(LevelId levelId) => throw UnimplementedError();
  @override
  Future<void> saveProgress(LevelId levelId, MoveCount moves) =>
      throw UnimplementedError();
  @override
  Future<void> markCompleted(LevelId levelId) => throw UnimplementedError();
  @override
  Future<bool> isCompleted(LevelId levelId) => throw UnimplementedError();
}

void main() {
  group('currentUserProvider', () {
    test('resolves the profile when the use case succeeds', () async {
      // Arrange
      final profile = UserProfile(
        id: 'u-1',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      );
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo(Right(profile))),
      ]);
      addTearDown(container.dispose);
      // Act
      final resolved = await container.read(currentUserProvider.future);
      // Assert
      expect(resolved, profile);
    });

    test('surfaces the AuthFailure as an error when the use case fails',
        () async {
      // Arrange
      final container = ProviderContainer(overrides: [
        authRepositoryProvider
            .overrideWithValue(_FakeAuthRepo(const Left(NetworkFailure()))),
      ]);
      addTearDown(container.dispose);
      // Act & Assert
      await expectLater(
        container.read(currentUserProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('progressTotalsProvider', () {
    test('reduces the local progress to stars and completed counts', () async {
      // Arrange
      final container = ProviderContainer(overrides: [
        levelProgressRepositoryProvider.overrideWithValue(_FakeProgressRepo([
          LevelProgress(
              levelId: LevelId('l1'), completed: true, bestStars: 3),
          LevelProgress(
              levelId: LevelId('l2'), completed: true, bestStars: 2),
          LevelProgress(levelId: LevelId('l3'), completed: false),
        ])),
      ]);
      addTearDown(container.dispose);
      // Act
      final totals = await container.read(progressTotalsProvider.future);
      // Assert
      expect(totals.totalStars, 5);
      expect(totals.completedLevels, 2);
    });
  });
}
