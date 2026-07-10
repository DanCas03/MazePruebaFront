import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/network/auth_token_interceptor.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';

import 'auth_token_interceptor_test.mocks.dart';

@GenerateMocks([IAuthTokenStorage])
void main() {
  late MockIAuthTokenStorage storage;
  late AuthTokenInterceptor interceptor;

  setUp(() {
    storage = MockIAuthTokenStorage();
    interceptor = AuthTokenInterceptor(storage);
  });

  test('adds Authorization header when a token is stored', () async {
    // Arrange
    when(storage.read()).thenAnswer((_) async => AuthToken('jwt-9'));
    final options = RequestOptions(path: '/scores');
    // Act
    await interceptor.attachToken(options);
    // Assert
    expect(options.headers['Authorization'], 'Bearer jwt-9');
  });

  test('leaves headers untouched when no token is stored', () async {
    // Arrange
    when(storage.read()).thenAnswer((_) async => null);
    final options = RequestOptions(path: '/scores');
    // Act
    await interceptor.attachToken(options);
    // Assert
    expect(options.headers.containsKey('Authorization'), isFalse);
  });
}
