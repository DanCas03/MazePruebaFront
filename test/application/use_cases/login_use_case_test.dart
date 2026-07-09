import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/use_cases/login_use_case.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';

import 'login_use_case_test.mocks.dart';

@GenerateMocks([IAuthRepository])
void main() {
  late MockIAuthRepository repo;
  late LoginUseCase useCase;

  setUp(() {
    repo = MockIAuthRepository();
    useCase = LoginUseCase(repo);
  });

  test('delegates to repo.login with a valid Email and returns its Right', () async {
    // Arrange
    final token = AuthToken('header.payload.sig');
    when(repo.login(any, any)).thenAnswer((_) async => Right(token));
    // Act
    final result = await useCase.execute('player@arrowmaze.com', 'sup3rs3cret');
    // Assert
    expect(result, Right<AuthFailure, AuthToken>(token));
    final captured = verify(repo.login(captureAny, captureAny)).captured;
    expect((captured[0] as Email).value, 'player@arrowmaze.com');
    expect(captured[1], 'sup3rs3cret');
  });

  test('forwards a repo Left failure unchanged', () async {
    // Arrange
    when(repo.login(any, any))
        .thenAnswer((_) async => const Left(InvalidCredentials()));
    // Act
    final result = await useCase.execute('player@arrowmaze.com', 'bad');
    // Assert
    expect(result, const Left<AuthFailure, AuthToken>(InvalidCredentials()));
  });

  test('returns Left(InvalidCredentials) without hitting repo on malformed email', () async {
    // Act
    final result = await useCase.execute('not-an-email', 'whatever12');
    // Assert
    expect(result, const Left<AuthFailure, AuthToken>(InvalidCredentials()));
    verifyNever(repo.login(any, any));
  });
}
