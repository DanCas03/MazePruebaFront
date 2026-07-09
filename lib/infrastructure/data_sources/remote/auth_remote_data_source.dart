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

  Future<String> register(String email, String password) async {
    final res = await _dio.post('/auth/register',
        data: {'email': email, 'password': password});
    return (res.data as Map)['token'] as String;
  }
}
