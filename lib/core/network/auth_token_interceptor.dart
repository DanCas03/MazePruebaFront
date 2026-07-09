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
  ///
  /// Gap conocido (a resolver en front#16/#17): el token se lee de
  /// [IAuthTokenStorage], que es persistente. Una sesión con
  /// `remember: false` (AuthController.saveSession con `persist: false`)
  /// vive solo en memoria (AuthState.Authenticated) y nunca se escribe aquí,
  /// así que sus llamadas salientes NO llevarán este header. Las próximas
  /// features de llamadas autenticadas deben leer el token desde
  /// AuthController/AuthState (o persistirlo igualmente para este
  /// interceptor) en vez de asumir que este adapter lo cubre siempre.
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
