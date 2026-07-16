import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/state/auth_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_form_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/domain/auth/failures/auth_failure.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_repository.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';

import '../../support/auth_fakes.dart';
import 'auth_form_controller_test.mocks.dart';

@GenerateMocks([IAuthRepository, IAuthTokenStorage])
void main() {
  late MockIAuthRepository repo;
  late MockIAuthTokenStorage storage;

  setUp(() {
    repo = MockIAuthRepository();
    storage = MockIAuthTokenStorage();
    when(storage.read()).thenAnswer((_) async => null); // start Unauthenticated
  });

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        authControllerProvider.overrideWith(
          () => AuthController(
              storage,
              RestoreSessionUseCase(storage),
              InMemorySessionTokenStore(),
              NoopUserScopedStorage()),
        ),
      ]);

  test('login success saves session (persist=remember) and ends FormIdle', () async {
    // Arrange
    final token = AuthToken('jwt-ok');
    when(repo.login(any, any)).thenAnswer((_) async => Right(token));
    when(storage.save(any)).thenAnswer((_) async {});
    final container = makeContainer();
    await container.read(authControllerProvider.future); // settle
    // Act
    await container
        .read(authFormControllerProvider.notifier)
        .login('a@b.com', 'secret12', remember: true);
    // Assert
    expect(container.read(authFormControllerProvider), isA<FormIdle>());
    verify(storage.save(token)).called(1);
  });

  test('register success saves session and ends FormIdle', () async {
    // Arrange
    final token = AuthToken('jwt-reg');
    when(repo.register(any, any, any)).thenAnswer((_) async => Right(token));
    when(storage.save(any)).thenAnswer((_) async {});
    final container = makeContainer();
    await container.read(authControllerProvider.future); // settle
    // Act
    await container
        .read(authFormControllerProvider.notifier)
        .register('a@b.com', 'player_01', 'secret12', remember: true);
    // Assert
    expect(container.read(authFormControllerProvider), isA<FormIdle>());
    verify(storage.save(token)).called(1);
  });

  test('login with remember:false does NOT persist but still authenticates', () async {
    // Arrange
    when(repo.login(any, any)).thenAnswer((_) async => Right(AuthToken('jwt-mem')));
    final container = makeContainer();
    await container.read(authControllerProvider.future);
    // Act
    await container
        .read(authFormControllerProvider.notifier)
        .login('a@b.com', 'secret12', remember: false);
    // Assert
    verifyNever(storage.save(any));
  });

  test('login failure sets FormError with the failure', () async {
    // Arrange
    when(repo.login(any, any))
        .thenAnswer((_) async => const Left(InvalidCredentials()));
    final container = makeContainer();
    await container.read(authControllerProvider.future);
    // Act
    await container
        .read(authFormControllerProvider.notifier)
        .login('a@b.com', 'bad', remember: true);
    // Assert
    final state = container.read(authFormControllerProvider);
    expect(state, isA<FormError>());
    expect((state as FormError).failure, isA<InvalidCredentials>());
  });

  test('emits FormSubmitting before resolving', () async {
    // Arrange — a completer keeps the use case pending so we can observe Submitting
    when(repo.login(any, any)).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return Right(AuthToken('jwt'));
    });
    when(storage.save(any)).thenAnswer((_) async {});
    final container = makeContainer();
    await container.read(authControllerProvider.future);
    final seen = <AuthFormState>[];
    container.listen(authFormControllerProvider, (_, next) => seen.add(next),
        fireImmediately: false);
    // Act
    final future = container
        .read(authFormControllerProvider.notifier)
        .login('a@b.com', 'secret12', remember: true);
    // Assert — Submitting observed synchronously after the call starts
    expect(container.read(authFormControllerProvider), isA<FormSubmitting>());
    await future;
    expect(seen.any((s) => s is FormSubmitting), isTrue);
  });
}
