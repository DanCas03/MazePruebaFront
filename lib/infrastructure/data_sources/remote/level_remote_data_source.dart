import 'package:dio/dio.dart';

/// Data source remoto de niveles: traduce a `GET /levels` y `GET /levels/:id`
/// (back#5, público) y devuelve el JSON crudo. No mapea errores (tarea del repo
/// adapter); propaga DioException hacia arriba. Sin clase DTO: el decoder es la
/// única fuente de verdad del parseo. Usa el Dio compuesto en main.
class LevelRemoteDataSource {
  final Dio _dio;
  LevelRemoteDataSource(this._dio);

  Future<List<dynamic>> fetchLevelIds() async {
    final res = await _dio.get('/levels');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchLevel(String id) async {
    final res = await _dio.get('/levels/$id');
    return res.data as Map<String, dynamic>;
  }
}
