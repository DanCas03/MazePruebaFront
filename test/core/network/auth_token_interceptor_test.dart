import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/network/auth_token_interceptor.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';

void main() {
  test('firma el request cuando el token vive solo en memoria (remember:false)',
      () {
    // Arrange — sesión sin persistencia: el token solo está en el store en memoria.
    final store = InMemorySessionTokenStore()..current = AuthToken('jwt-9');
    final interceptor = AuthTokenInterceptor(store);
    final options = RequestOptions(path: '/scores');
    // Act
    interceptor.attachToken(options);
    // Assert
    expect(options.headers['Authorization'], 'Bearer jwt-9');
  });

  test('deja los headers intactos cuando no hay sesión activa', () {
    // Arrange
    final store = InMemorySessionTokenStore();
    final interceptor = AuthTokenInterceptor(store);
    final options = RequestOptions(path: '/scores');
    // Act
    interceptor.attachToken(options);
    // Assert
    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
