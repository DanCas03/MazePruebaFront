import 'package:dio/dio.dart';

import '../../domain/auth/repositories/i_auth_token_storage.dart';
import '../config/app_config.dart';
import 'auth_token_interceptor.dart';

/// Factoría del cliente Dio de la app: fija la URL base (AppConfig) y engancha
/// el interceptor de token. Único punto de construcción del HTTP client (SRP).
class DioClient {
  DioClient._();

  static Dio create(IAuthTokenStorage storage) {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    dio.interceptors.add(AuthTokenInterceptor(storage));
    return dio;
  }
}
