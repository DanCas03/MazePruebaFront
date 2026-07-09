import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'package:flutter_arrow_maze/core/config/app_config.dart';
import 'package:flutter_arrow_maze/core/network/auth_token_interceptor.dart';
import 'package:flutter_arrow_maze/core/network/dio_client.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';

import 'dio_client_test.mocks.dart';

@GenerateMocks([IAuthTokenStorage])
void main() {
  test('creates a Dio with the configured base URL and the token interceptor', () {
    // Arrange
    final storage = MockIAuthTokenStorage();
    // Act
    final dio = DioClient.create(storage);
    // Assert
    expect(dio.options.baseUrl, AppConfig.apiBaseUrl);
    expect(dio.interceptors.whereType<AuthTokenInterceptor>().length, 1);
  });
}
