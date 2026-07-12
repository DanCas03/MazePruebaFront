import 'package:dio/dio.dart';

/// Data source remoto de niveles: traduce a `GET /levels` y `GET /levels/:id`
/// (back#5, público) y devuelve el JSON crudo. No mapea errores (tarea del repo
/// adapter); propaga DioException hacia arriba. Sin clase DTO: el decoder es la
/// única fuente de verdad del parseo. Usa el Dio compuesto en main.
///
/// Guarda de FORMA del cuerpo 200: un catálogo debe ser una lista y un nivel un
/// objeto JSON. Una forma inesperada (envelope `{items:[...]}`, HTML/string de un
/// proxy) lanza `FormatException` — que el repo mapea a `LevelCorrupted` — en vez
/// de un `TypeError` crudo NO capturado que escaparía el contrato de fallos.
class LevelRemoteDataSource {
  final Dio _dio;
  LevelRemoteDataSource(this._dio);

  Future<List<dynamic>> fetchLevelIds() async {
    final res = await _dio.get('/levels');
    final data = res.data;
    if (data is! List) {
      throw FormatException(
          'expected a JSON list from /levels, got ${data.runtimeType}');
    }
    return data;
  }

  Future<Map<String, dynamic>> fetchLevel(String id) async {
    final res = await _dio.get('/levels/$id');
    final data = res.data;
    if (data is! Map) {
      throw FormatException(
          'expected a JSON object from /levels/$id, got ${data.runtimeType}');
    }
    return data.cast<String, dynamic>();
  }
}
