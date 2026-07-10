import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/state/auth_controller.dart';
import 'package:flutter_arrow_maze/application/state/auth_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';

import 'auth_controller_test.mocks.dart';

/// Token cuyo `exp` cae en el año 2100: nunca expirado sin importar el reloj real.
AuthToken _longLivedToken() {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.utc(2100).millisecondsSinceEpoch ~/ 1000;
  return AuthToken('${seg({'alg': 'HS256'})}.${seg({'sub': 'u1', 'exp': exp})}.sig');
}

@GenerateMocks([IAuthTokenStorage])
void main() {
  late MockIAuthTokenStorage mockStorage;
  late InMemorySessionTokenStore session;

  setUp(() {
    mockStorage = MockIAuthTokenStorage();
    session = InMemorySessionTokenStore();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(overrides: [
      authControllerProvider.overrideWith(
        () => AuthController(
            mockStorage, RestoreSessionUseCase(mockStorage), session),
      ),
    ]);
  }

  group('build (auto-login on startup)', () {
    test('restores Authenticated y fija la sesión viva cuando hay token válido',
        () async {
      // Arrange
      final token = _longLivedToken();
      when(mockStorage.read()).thenAnswer((_) async => token);
      final container = makeContainer();
      // Act
      final state = await container.read(authControllerProvider.future);
      // Assert
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).token, token);
      expect(session.current, token); // el interceptor verá el token restaurado
    });

    test('resolves to Unauthenticated cuando no hay token guardado', () async {
      // Arrange
      when(mockStorage.read()).thenAnswer((_) async => null);
      final container = makeContainer();
      // Act
      final state = await container.read(authControllerProvider.future);
      // Assert
      expect(state, isA<Unauthenticated>());
      expect(session.current, isNull);
    });

    test(
        'build limpia un token previo de la sesión cuando el restore no autentica',
        () async {
      // Arrange
      session.current = AuthToken('stale-token');
      when(mockStorage.read()).thenAnswer((_) async => null);
      final container = makeContainer();
      // Act
      final state = await container.read(authControllerProvider.future);
      // Assert
      expect(state, isA<Unauthenticated>());
      expect(session.current, isNull);
    });
  });

  group('saveSession', () {
    test('persist:true escribe storage Y fija la sesión viva', () async {
      // Arrange
      when(mockStorage.read()).thenAnswer((_) async => null);
      final token = _longLivedToken();
      when(mockStorage.save(token)).thenAnswer((_) async {});
      final container = makeContainer();
      await container.read(authControllerProvider.future); // settle build()
      // Act
      await container.read(authControllerProvider.notifier).saveSession(token);
      // Assert
      final state = await container.read(authControllerProvider.future);
      expect(state, isA<Authenticated>());
      verify(mockStorage.save(token)).called(1);
      expect(session.current, token);
    });

    test('persist:false fija la sesión viva SIN escribir storage', () async {
      // Arrange
      when(mockStorage.read()).thenAnswer((_) async => null);
      final token = _longLivedToken();
      final container = makeContainer();
      await container.read(authControllerProvider.future); // settle build()
      // Act
      await container
          .read(authControllerProvider.notifier)
          .saveSession(token, persist: false);
      // Assert
      final state = await container.read(authControllerProvider.future);
      expect(state, isA<Authenticated>());
      verifyNever(mockStorage.save(any));
      expect(session.current, token); // clave: el interceptor firmará igual
    });
  });

  group('signOut', () {
    test('limpia storage Y la sesión viva, y pasa a Unauthenticated', () async {
      // Arrange — arranca autenticado
      final token = _longLivedToken();
      when(mockStorage.read()).thenAnswer((_) async => token);
      when(mockStorage.clear()).thenAnswer((_) async {});
      final container = makeContainer();
      await container.read(authControllerProvider.future);
      // Act
      await container.read(authControllerProvider.notifier).signOut();
      // Assert
      final state = await container.read(authControllerProvider.future);
      expect(state, isA<Unauthenticated>());
      verify(mockStorage.clear()).called(1);
      expect(session.current, isNull);
    });

    test(
        'signOut limpia sesión y pasa a Unauthenticated aunque storage.clear falle',
        () async {
      // Arrange — arranca autenticado
      final token = _longLivedToken();
      when(mockStorage.read()).thenAnswer((_) async => token);
      when(mockStorage.clear()).thenThrow(Exception('keychain down'));
      final container = makeContainer();
      await container.read(authControllerProvider.future); // settle build()
      // Act / Assert
      await expectLater(
        container.read(authControllerProvider.notifier).signOut(),
        throwsA(anything),
      );
      // Assert
      expect(session.current, isNull);
      final state = await container.read(authControllerProvider.future);
      expect(state, isA<Unauthenticated>());
    });
  });
}
