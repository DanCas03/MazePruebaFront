import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/register_use_case.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';

import 'register_use_case_test.mocks.dart';

@GenerateMocks([IAuthRepository])
void main() {
  late MockIAuthRepository repo;
  late RegisterUseCase useCase;

  setUp(() {
    repo = MockIAuthRepository();
    useCase = RegisterUseCase(repo);
  });

  test('delegates to repo.register with valid email + username + password and returns Right', () async {
    // Arrange
    final token = AuthToken('header.payload.sig');
    when(repo.register(any, any, any)).thenAnswer((_) async => Right(token));
    // Act
    final result = await useCase.execute(
        'new@arrowmaze.com', 'player_01', 'sup3rs3cret');
    // Assert
    expect(result, Right<AuthFailure, AuthToken>(token));
    final captured =
        verify(repo.register(captureAny, captureAny, captureAny)).captured;
    expect((captured[0] as Email).value, 'new@arrowmaze.com');
    expect(captured[1], 'player_01');
    expect(captured[2], 'sup3rs3cret');
  });

  test('forwards EmailAlreadyRegistered from repo', () async {
    // Arrange
    when(repo.register(any, any, any))
        .thenAnswer((_) async => const Left(EmailAlreadyRegistered()));
    // Act
    final result = await useCase.execute(
        'taken@arrowmaze.com', 'player_01', 'sup3rs3cret');
    // Assert
    expect(result, const Left<AuthFailure, AuthToken>(EmailAlreadyRegistered()));
  });

  test('returns Left without hitting repo when password shorter than 8', () async {
    // Act
    final result =
        await useCase.execute('new@arrowmaze.com', 'player_01', 'short');
    // Assert
    expect(result, isA<Left>());
    verifyNever(repo.register(any, any, any));
  });

  test('returns Left without hitting repo when username is invalid', () async {
    // Act — 2 chars, below Username.minLength (3)
    final result =
        await useCase.execute('new@arrowmaze.com', 'ab', 'sup3rs3cret');
    // Assert
    expect(result, isA<Left>());
    verifyNever(repo.register(any, any, any));
  });
}
