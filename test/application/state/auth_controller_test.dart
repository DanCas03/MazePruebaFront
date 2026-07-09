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

  setUp(() => mockStorage = MockIAuthTokenStorage());

  ProviderContainer makeContainer() {
    return ProviderContainer(overrides: [
      authControllerProvider.overrideWith(
        () => AuthController(mockStorage, RestoreSessionUseCase(mockStorage)),
      ),
    ]);
  }

  group('build (auto-login on startup)', () {
    test('restores Authenticated when a valid token is stored', () async {
      // Arrange
      final token = _longLivedToken();
      when(mockStorage.read()).thenAnswer((_) async => token);
      final container = makeContainer();
      // Act
      final state = await container.read(authControllerProvider.future);
      // Assert
      expect(state, isA<Authenticated>());
      expect((state as Authenticated).token, token);
    });

    test('resolves to Unauthenticated when no token is stored', () async {
      // Arrange
      when(mockStorage.read()).thenAnswer((_) async => null);
      final container = makeContainer();
      // Act
      final state = await container.read(authControllerProvider.future);
      // Assert
      expect(state, isA<Unauthenticated>());
    });
  });

  group('saveSession', () {
    test('persists the token and transitions to Authenticated', () async {
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
    });
  });

  group('signOut', () {
    test('clears storage and transitions to Unauthenticated', () async {
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
    });
  });
}
