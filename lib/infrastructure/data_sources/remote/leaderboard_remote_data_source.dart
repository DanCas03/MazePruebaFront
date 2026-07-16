import 'package:dio/dio.dart';

/// Data source remoto del leaderboard. Traduce el puerto a las rutas HTTP del
/// back (`POST /scores`, back#7; `GET /leaderboard/:levelId`, back#9) usando el
/// Dio compuesto en main (con AuthTokenInterceptor). Propaga DioException hacia
/// el repo, que decide el mapeo de errores.
class LeaderboardRemoteDataSource {
  final Dio _dio;
  LeaderboardRemoteDataSource(this._dio);

  /// Envía las métricas crudas del run y devuelve el JSON de respuesta con el
  /// resultado CANÓNICO (`{score, stars}`, ADR 0006).
  Future<Map<String, dynamic>> postScore(Map<String, dynamic> body) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/scores', data: body);
    return response.data ?? const {};
  }

  /// Lee el ranking GENERAL de jugadores (`GET /leaderboard`, ADR 0006;
  /// autenticado — el back necesita saber quién pregunta para adjuntar la fila
  /// `me`). Devuelve el JSON crudo `{top, me}`.
  Future<Map<String, dynamic>> fetchGlobalLeaderboard() async {
    final response = await _dio.get<Map<String, dynamic>>('/leaderboard');
    return response.data ?? const {};
  }

  /// Lee el ranking de un nivel (endpoint público). El `limit` opcional acota el
  /// top-N solicitado; el back aplica su propio default y máximo. Devuelve las
  /// filas crudas del JSON.
  Future<List<dynamic>> fetchLeaderboard(String levelId, {int? limit}) async {
    final response = await _dio.get<List<dynamic>>(
      '/leaderboard/$levelId',
      queryParameters: limit != null ? {'limit': limit} : null,
    );
    return response.data ?? const [];
  }
}
