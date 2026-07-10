import 'package:dio/dio.dart';

/// Data source remoto de progreso: traduce a llamadas HTTP contra `/progress`
/// del back y devuelve el JSON crudo. No mapea errores (tarea del repo adapter);
/// propaga DioException hacia arriba. Usa el Dio compuesto en main (con el
/// AuthTokenInterceptor).
class RemoteProgressDataSource {
  final Dio _dio;
  RemoteProgressDataSource(this._dio);

  Future<List<dynamic>> getProgress() async {
    final res = await _dio.get('/progress');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> postProgress(List<Map<String, dynamic>> levels) async {
    final res = await _dio.post('/progress', data: {'levels': levels});
    return res.data as List<dynamic>;
  }
}
