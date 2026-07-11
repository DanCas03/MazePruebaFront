import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/config/app_config.dart';
import 'package:flutter_arrow_maze/core/network/auth_token_interceptor.dart';
import 'package:flutter_arrow_maze/core/network/dio_client.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';

void main() {
  test('crea un Dio con la URL base configurada y el interceptor de token', () {
    // Arrange / Act
    final dio = DioClient.create(InMemorySessionTokenStore());
    // Assert
    expect(dio.options.baseUrl, AppConfig.apiBaseUrl);
    expect(dio.interceptors.whereType<AuthTokenInterceptor>().length, 1);
  });
}
