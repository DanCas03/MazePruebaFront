import 'package:dio/dio.dart';

/// Data source remoto del leaderboard: traduce a `POST /scores` (back#7) y
/// devuelve nada. Usa el Dio compuesto en main (con AuthTokenInterceptor);
/// propaga DioException hacia el repo.
class LeaderboardRemoteDataSource {
  final Dio _dio;
  LeaderboardRemoteDataSource(this._dio);

  Future<void> postScore(Map<String, dynamic> body) async {
    await _dio.post('/scores', data: body);
  }
}
