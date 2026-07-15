import 'package:dio/dio.dart';

/// Data source remoto de auth: traduce credenciales a llamadas HTTP contra
/// /auth del back y devuelve el token crudo. No mapea errores (eso es tarea del
/// repositorio adaptador); propaga DioException hacia arriba.
class AuthRemoteDataSource {
  final Dio _dio;
  AuthRemoteDataSource(this._dio);

  Future<String> login(String email, String password) async {
    final res = await _dio.post('/auth/login',
        data: {'email': email, 'password': password});
    return (res.data as Map)['token'] as String;
  }

  Future<String> register(
      String email, String username, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
    });
    return (res.data as Map)['token'] as String;
  }

  /// GET /auth/me: perfil del usuario autenticado (`{ id, username, email }`).
  /// El interceptor firma la llamada con el token vivo. Devuelve el JSON crudo;
  /// el mapeo a dominio y de errores es tarea del repositorio adaptador.
  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return (res.data as Map).cast<String, dynamic>();
  }
}
