import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/level_remote_data_source.dart';

import 'level_remote_data_source_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late MockDio dio;
  late LevelRemoteDataSource dataSource;

  setUp(() {
    dio = MockDio();
    dataSource = LevelRemoteDataSource(dio);
  });

  Response<dynamic> ok(String path, Object? data) => Response(
        requestOptions: RequestOptions(path: path),
        data: data,
        statusCode: 200,
      );

  test('should_return_raw_list_when_fetchLevelIds_calls_GET_levels', () async {
    // Arrange
    final rawLevels = [
      {'levelId': 'level-01'},
      {'levelId': 'level-02'},
    ];
    when(dio.get('/levels'))
        .thenAnswer((_) async => ok('/levels', rawLevels));
    // Act
    final result = await dataSource.fetchLevelIds();
    // Assert
    expect(result, rawLevels);
    verify(dio.get('/levels')).called(1);
  });

  test('should_return_raw_map_when_fetchLevel_calls_GET_levels_id', () async {
    // Arrange
    final rawLevel = {
      'levelId': 'level-01',
      'cols': 4,
      'rows': 4,
      'arrows': [],
    };
    when(dio.get('/levels/level-01'))
        .thenAnswer((_) async => ok('/levels/level-01', rawLevel));
    // Act
    final result = await dataSource.fetchLevel('level-01');
    // Assert
    expect(result, rawLevel);
    verify(dio.get('/levels/level-01')).called(1);
  });

  test('should_propagate_DioException_when_fetchLevelIds_fails', () async {
    // Arrange
    when(dio.get('/levels')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/levels'),
        type: DioExceptionType.connectionError,
      ),
    );
    // Act / Assert
    expect(() => dataSource.fetchLevelIds(), throwsA(isA<DioException>()));
  });

  test('should_propagate_DioException_when_fetchLevel_fails', () async {
    // Arrange
    when(dio.get('/levels/level-01')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/levels/level-01'),
        type: DioExceptionType.connectionError,
      ),
    );
    // Act / Assert
    expect(
      () => dataSource.fetchLevel('level-01'),
      throwsA(isA<DioException>()),
    );
  });

  test('should_throw_FormatException_when_fetchLevelIds_body_is_not_a_list',
      () async {
    // Arrange — un 200 cuyo cuerpo NO es una lista (p. ej. envelope `{items:...}`
    // de un proxy). Antes de la guarda de forma, `res.data as List` lanzaba un
    // TypeError crudo NO capturado; ahora debe emerger como FormatException para
    // que el repo lo mapee a LevelCorrupted (contrato de fallos).
    when(dio.get('/levels'))
        .thenAnswer((_) async => ok('/levels', {'items': []}));
    // Act / Assert
    expect(() => dataSource.fetchLevelIds(), throwsA(isA<FormatException>()));
  });

  test('should_throw_FormatException_when_fetchLevel_body_is_not_a_map',
      () async {
    // Arrange — un 200 cuyo cuerpo es una lista en vez de un objeto de nivel.
    // `res.data as Map` lanzaría un TypeError crudo; ahora es FormatException.
    when(dio.get('/levels/level-01')).thenAnswer(
        (_) async => ok('/levels/level-01', [1, 2, 3]));
    // Act / Assert
    expect(
      () => dataSource.fetchLevel('level-01'),
      throwsA(isA<FormatException>()),
    );
  });
}
