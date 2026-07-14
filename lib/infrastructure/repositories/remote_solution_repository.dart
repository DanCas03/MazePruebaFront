import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/value_objects/arrow_id.dart';
import '../../domain/board/failures/solution_failure.dart';
import '../../domain/board/repositories/i_solution_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../data_sources/remote/solution_remote_data_source.dart';

/// Adapter del puerto [ISolutionRepository] (#32). Pide la Solución al back
/// (`GET /levels/:id/solution`) y la parsea a `List<ArrowId>` en el orden de
/// vaciado —la lengua del cable son ids planos (CONTEXT-MAP)—. Aquí muere
/// [DioException]; ninguna capa superior conoce HTTP. Logging vía
/// [ILoggerService] (AOP; nunca print).
///
/// Sin caché: la pista es on-demand y no bloquea la partida, así que un timeout
/// o una red caída resuelven [SolutionUnavailable] (la UI avisa y conserva la
/// partida) en vez de servir una copia vieja como hace el repo de niveles.
class RemoteSolutionRepository implements ISolutionRepository {
  final SolutionRemoteDataSource _remote;
  final ILoggerService _logger;

  RemoteSolutionRepository(this._remote, this._logger);

  static const _ctx = 'RemoteSolutionRepository';

  @override
  Future<Either<SolutionFailure, List<ArrowId>>> getSolution(LevelId id) async {
    try {
      final raw = await _remote.fetchSolution(id.value);
      return Right(_parseOrder(raw)); // FormatException si el JSON es corrupto
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) return Left(SolutionNotFound(id));
      if (status == 422) return Left(SolutionUnsolvable(id));
      // Red, timeout (connect/receive/send) o error de servidor no-4xx: la
      // pista no está disponible ahora. La partida sigue intacta; la UI avisa.
      _logger.warn('solution unavailable for ${id.value}: ${e.type}', _ctx);
      return const Left(SolutionUnavailable());
    } on FormatException catch (e) {
      _logger.error('solution ${id.value} corrupted: ${e.message}', _ctx, e);
      return Left(SolutionCorrupted(e.message));
    }
  }

  List<ArrowId> _parseOrder(Map<String, dynamic> raw) {
    try {
      final list = raw['solution'] as List;
      return [for (final item in list) ArrowId(item as String)];
    } catch (e) {
      throw FormatException('malformed solution: $e');
    }
  }
}
