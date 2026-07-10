import 'package:dio/dio.dart';

import '../../domain/auth/repositories/i_session_token_store.dart';

/// AOP + Adapter: inyecta `Authorization: Bearer <token>` en cada request
/// saliente leyendo el token de la SESIÓN VIVA (ISessionTokenStore, en memoria),
/// para que las llamadas autenticadas (front#16/#17) no repitan ese boilerplate.
///
/// Lee de la sesión en memoria (no del almacenamiento persistente) para cubrir
/// también las sesiones `remember:false`: el token está en el store durante toda
/// la sesión aunque nunca se escriba en keychain. Sin sesión activa (login/
/// registro) no hay token: no añade el header.
class AuthTokenInterceptor extends Interceptor {
  final ISessionTokenStore _session;
  AuthTokenInterceptor(this._session);

  /// Extraído de [onRequest] para testear la lógica del header sin fabricar un
  /// RequestInterceptorHandler de Dio. Síncrono: el token vive en memoria.
  void attachToken(RequestOptions options) {
    final token = _session.current;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer ${token.value}';
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    attachToken(options);
    handler.next(options);
  }
}
