import 'package:dio/dio.dart';

/// Data source remoto del leaderboard. Traduce el puerto a las rutas HTTP del
/// back (`POST /scores`, back#7; `GET /leaderboard/:levelId`, back#9) usando el
/// Dio compuesto en main (con AuthTokenInterceptor). Propaga DioException hacia
/// el repo, que decide el mapeo de errores.
class LeaderboardRemoteDataSource {
  final Dio _dio;
  LeaderboardRemoteDataSource(this._dio);

  Future<void> postScore(Map<String, dynamic> body) async {
    await _dio.post('/scores', data: body);
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
