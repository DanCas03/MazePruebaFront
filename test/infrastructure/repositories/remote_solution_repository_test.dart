import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/board/failures/solution_failure.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/solution_remote_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_solution_repository.dart';

// ── Dobles de test hechos a mano (sin build_runner) ──────────────────────────

/// Data source falso: lanza [error] si se fijó, o devuelve [payload]. Implementa
/// la interfaz pública del data source real (solo `fetchSolution`).
class _FakeSolutionDataSource implements SolutionRemoteDataSource {
  Object? error;
  Map<String, dynamic>? payload;

  @override
  Future<Map<String, dynamic>> fetchSolution(String id) async {
    if (error != null) throw error!;
    return payload!;
  }
}

/// Logger silencioso: el repo registra warn/error de diagnóstico; en tests no
/// queremos ruido en consola ni dependencias de infraestructura.
class _SilentLogger implements ILoggerService {
  @override
  void log(String message, String context) {}
  @override
  void warn(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
}

/// [DioException] como las que propaga el data source: con `status` para un
/// error de respuesta HTTP, o solo con `type` para red/timeout (sin `response`).
DioException _dioError({
  int? status,
  DioExceptionType type = DioExceptionType.badResponse,
}) =>
    DioException(
      requestOptions: RequestOptions(path: '/levels/7/solution'),
      type: type,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/levels/7/solution'),
              statusCode: status,
            ),
    );

void main() {
  late _FakeSolutionDataSource remote;
  late RemoteSolutionRepository repo;

  setUp(() {
    remote = _FakeSolutionDataSource();
    repo = RemoteSolutionRepository(remote, _SilentLogger());
  });

  test('should_parse_arrow_ids_in_order_when_network_succeeds', () async {
    // Arrange — wire contract: { levelId, solution: [ids] } en orden de vaciado.
    remote.payload = {
      'levelId': '7',
      'solution': ['a2', 'a0', 'a1'],
    };
    // Act
    final result = await repo.getSolution(LevelId('7'));
    // Assert — ids planos mapeados a ArrowId, respetando el orden del servidor.
    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected Right'),
      (order) => expect(
        order,
        [const ArrowId('a2'), const ArrowId('a0'), const ArrowId('a1')],
      ),
    );
  });

  test('should_return_SolutionNotFound_when_network_returns_404', () async {
    remote.error = _dioError(status: 404);
    final result = await repo.getSolution(LevelId('7'));
    expect(result, Left<SolutionFailure, List<ArrowId>>(SolutionNotFound(LevelId('7'))));
  });

  test('should_return_SolutionUnsolvable_when_network_returns_422', () async {
    remote.error = _dioError(status: 422);
    final result = await repo.getSolution(LevelId('7'));
    expect(
      result,
      Left<SolutionFailure, List<ArrowId>>(SolutionUnsolvable(LevelId('7'))),
    );
  });

  test('should_return_SolutionUnavailable_when_request_times_out', () async {
    // Arrange — timeout estricto de recepción (el back no respondió a tiempo).
    remote.error = _dioError(type: DioExceptionType.receiveTimeout);
    // Act
    final result = await repo.getSolution(LevelId('7'));
    // Assert — se rompe limpio como "no disponible"; la partida sigue intacta.
    expect(
      result,
      const Left<SolutionFailure, List<ArrowId>>(SolutionUnavailable()),
    );
  });

  test('should_return_SolutionUnavailable_when_server_error_non_4xx', () async {
    remote.error = _dioError(status: 500);
    final result = await repo.getSolution(LevelId('7'));
    expect(
      result,
      const Left<SolutionFailure, List<ArrowId>>(SolutionUnavailable()),
    );
  });

  test('should_return_SolutionCorrupted_when_data_source_reports_shape_violation',
      () async {
    // Arrange — cuerpo 200 con forma inesperada: el data source lanza
    // FormatException, que el repo mapea a SolutionCorrupted.
    remote.error = const FormatException('bad shape');
    final result = await repo.getSolution(LevelId('7'));
    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<SolutionCorrupted>()),
      (_) => fail('expected Left(SolutionCorrupted)'),
    );
  });

  test('should_return_SolutionCorrupted_when_payload_lacks_solution_key',
      () async {
    // Arrange — objeto JSON válido pero sin la clave `solution`.
    remote.payload = {'levelId': '7'};
    final result = await repo.getSolution(LevelId('7'));
    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<SolutionCorrupted>()),
      (_) => fail('expected Left(SolutionCorrupted)'),
    );
  });

  test('should_return_SolutionCorrupted_when_solution_entries_are_not_strings',
      () async {
    // Arrange — `solution` presente pero con entradas no-string (int).
    remote.payload = {
      'levelId': '7',
      'solution': [1, 2, 3],
    };
    final result = await repo.getSolution(LevelId('7'));
    expect(result.isLeft(), isTrue);
    result.fold(
      (f) => expect(f, isA<SolutionCorrupted>()),
      (_) => fail('expected Left(SolutionCorrupted)'),
    );
  });
}
