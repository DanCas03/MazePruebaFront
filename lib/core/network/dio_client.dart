import 'package:dio/dio.dart';

import '../../domain/auth/repositories/i_session_token_store.dart';
import '../config/app_config.dart';
import 'auth_token_interceptor.dart';

/// Factoría del cliente Dio de la app: fija la URL base (AppConfig) y engancha
/// el interceptor de token leyendo la sesión viva. Único punto de construcción
/// del HTTP client (SRP).
class DioClient {
  DioClient._();

  static Dio create(ISessionTokenStore session) {
    final dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    dio.interceptors.add(AuthTokenInterceptor(session));
    return dio;
  }
}
