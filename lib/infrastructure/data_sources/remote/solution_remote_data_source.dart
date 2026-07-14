import 'package:dio/dio.dart';

/// Data source remoto de la Solución de un nivel: traduce a
/// `GET /levels/:id/solution` (back#19, público) y devuelve el JSON crudo. No
/// mapea errores (tarea del repo adapter); propaga [DioException] hacia arriba.
///
/// Timeout ESTRICTO por request: la pista es una comodidad, no una ruta
/// bloqueante, así que se le impone un límite más corto que el global del Dio
/// (via [Options]). Si el back tarda, la llamada se rompe rápido con un
/// `receiveTimeout` en vez de colgar la bombilla en estado de carga.
///
/// Guarda de FORMA del cuerpo 200: la solución debe ser un objeto JSON; una
/// forma inesperada (lista, HTML/string de un proxy) lanza [FormatException]
/// —que el repo mapea a `SolutionCorrupted`— en vez de un `TypeError` crudo NO
/// capturado que escaparía el contrato de fallos.
class SolutionRemoteDataSource {
  final Dio _dio;
  final Duration _timeout;

  SolutionRemoteDataSource(
    this._dio, {
    Duration timeout = const Duration(seconds: 5),
  }) : _timeout = timeout;

  Future<Map<String, dynamic>> fetchSolution(String id) async {
    final res = await _dio.get<dynamic>(
      '/levels/$id/solution',
      options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
    );
    final data = res.data;
    if (data is! Map) {
      throw FormatException(
          'expected a JSON object from /levels/$id/solution, got ${data.runtimeType}');
    }
    return data.cast<String, dynamic>();
  }
}
