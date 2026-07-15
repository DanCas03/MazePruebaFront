import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/get_current_user_use_case.dart';
import 'package:flutter_arrow_maze/domain/auth/entities/user_profile.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/username.dart';

import 'get_current_user_use_case_test.mocks.dart';

@GenerateMocks([IAuthRepository])
void main() {
  late MockIAuthRepository repo;
  late GetCurrentUserUseCase useCase;

  setUp(() {
    repo = MockIAuthRepository();
    useCase = GetCurrentUserUseCase(repo);
  });

  test('returns the profile from repo.me on success', () async {
    // Arrange
    final profile = UserProfile(
      id: 'u-1',
      username: Username('player_01'),
      email: Email('player@arrowmaze.com'),
    );
    when(repo.me()).thenAnswer((_) async => Right(profile));
    // Act
    final result = await useCase.execute();
    // Assert
    expect(result, Right<AuthFailure, UserProfile>(profile));
    verify(repo.me()).called(1);
  });

  test('forwards a repo Left failure unchanged', () async {
    // Arrange
    when(repo.me()).thenAnswer((_) async => const Left(InvalidCredentials()));
    // Act
    final result = await useCase.execute();
    // Assert
    expect(result, const Left<AuthFailure, UserProfile>(InvalidCredentials()));
  });
}
