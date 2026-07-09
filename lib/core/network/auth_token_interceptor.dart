import 'package:dio/dio.dart';

import '../../domain/auth/repositories/i_auth_token_storage.dart';

/// AOP + Adapter: inyecta `Authorization: Bearer <token>` en cada request
/// saliente leyendo el token del almacenamiento seguro, para que las llamadas
/// autenticadas (front#16/#17) no repitan ese boilerplate. En login/registro
/// aún no hay token: no añade el header.
class AuthTokenInterceptor extends Interceptor {
  final IAuthTokenStorage _storage;
  AuthTokenInterceptor(this._storage);

  /// Extraído de [onRequest] para poder testear la lógica del header sin
  /// fabricar un RequestInterceptorHandler de Dio.
  Future<void> attachToken(RequestOptions options) async {
    final token = await _storage.read();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }
  }

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    await attachToken(options);
    handler.next(options);
  }
}
