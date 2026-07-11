import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/local/level_cache_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/remote/level_remote_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/remote_level_repository.dart';
import 'package:flutter_arrow_maze/infrastructure/serialization/level_json_decoder.dart';

import 'remote_level_repository_test.mocks.dart';

/// Construye una [DioException] como las que propaga [LevelRemoteDataSource]:
/// con `status` para un error de respuesta HTTP (p. ej. 404) o solo con `type`
/// para un fallo de red/timeout (sin `response`). Espejo del helper del test de
/// auth, para mantener el mismo estilo mockito en toda la infraestructura.
DioException _dioError({
  int? status,
  DioExceptionType type = DioExceptionType.badResponse,
}) =>
    DioException(
      requestOptions: RequestOptions(path: '/levels'),
      type: type,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/levels'),
              statusCode: status,
            ),
    );

@GenerateMocks([LevelRemoteDataSource, LevelCacheDataSource, ILoggerService])
void main() {
  late MockLevelRemoteDataSource remote;
  late MockLevelCacheDataSource cache;
  late MockILoggerService logger;
  late RemoteLevelRepository repo;

  // El decoder es puro: se inyecta la implementación real (no un mock) para que
  // el test ejercite el parseo de verdad (network-first + caché + decode).
  const decoder = LevelJsonDecoder();

  // Mapa crudo canónico del wire contract y su forma serializada (lo que la
  // caché persiste). Un único nivel válido: flecha recta de 2 celdas en 4x4.
  final rawLevel = <String, dynamic>{
    'levelId': 'level-01',
    'cols': 4,
    'rows': 4,
    'arrows': [
      {
        'id': 'a1',
        'headDir': 'right',
        'cells': [
          [0, 0],
          [0, 1],
        ],
      },
    ],
  };
  final rawLevelJson = jsonEncode(rawLevel);

  setUp(() {
    remote = MockLevelRemoteDataSource();
    cache = MockLevelCacheDataSource();
    logger = MockILoggerService();
    repo = RemoteLevelRepository(remote, cache, decoder, logger);
    // Write-through: los métodos de escritura de la caché son awaited.
    when(cache.writeLevel(any, any)).thenAnswer((_) async {});
    when(cache.writeCatalog(any)).thenAnswer((_) async {});
  });

  group('getLevel', () {
    test('should_return_level_and_write_through_when_network_succeeds',
        () async {
      // Arrange
      when(remote.fetchLevel('level-01')).thenAnswer((_) async => rawLevel);
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert
      expect(result.isRight(), isTrue);
      expect(result, Right<LevelFailure, Level>(decoder.decode(rawLevel)));
      // Bloquea el FORMATO del write-through, no solo que ocurrió: captura el
      // payload y afirma que es `jsonEncode(rawLevel)`. Sin esto, una regresión
      // a `raw.toString()` dejaría todos los tests verdes rompiendo el fallback
      // offline real (la caché guarda el crudo re-serializado, no un toString).
      final captured =
          verify(cache.writeLevel('level-01', captureAny)).captured.single;
      expect(captured, rawLevelJson);
    });

    test('should_return_cached_level_when_network_fails_and_cache_hit',
        () async {
      // Arrange
      when(remote.fetchLevel('level-01'))
          .thenThrow(_dioError(type: DioExceptionType.connectionError));
      when(cache.readLevel('level-01')).thenReturn(rawLevelJson);
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert
      expect(result.isRight(), isTrue);
      expect(result, Right<LevelFailure, Level>(decoder.decode(rawLevel)));
    });

    test('should_return_LevelNotFound_and_skip_cache_when_network_returns_404',
        () async {
      // Arrange
      when(remote.fetchLevel('level-01')).thenThrow(_dioError(status: 404));
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert — el back es autoridad sobre la existencia: la caché no se toca.
      expect(result, Left<LevelFailure, Level>(LevelNotFound(LevelId('level-01'))));
      verifyNever(cache.readLevel(any));
    });

    test('should_return_LevelCorrupted_when_network_payload_is_malformed',
        () async {
      // Arrange — mapa de red sin la clave obligatoria `cols`.
      final corrupt = <String, dynamic>{
        'levelId': 'level-01',
        'rows': 4,
        'arrows': [
          {
            'id': 'a1',
            'headDir': 'right',
            'cells': [
              [0, 0],
              [0, 1],
            ],
          },
        ],
      };
      when(remote.fetchLevel('level-01')).thenAnswer((_) async => corrupt);
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<LevelCorrupted>()),
        (_) => fail('expected Left(LevelCorrupted)'),
      );
      verifyNever(cache.writeLevel(any, any));
    });

    test('should_return_LevelCorrupted_when_cached_payload_is_malformed',
        () async {
      // Arrange — red caída y la copia en caché no es JSON válido.
      when(remote.fetchLevel('level-01'))
          .thenThrow(_dioError(type: DioExceptionType.connectionError));
      when(cache.readLevel('level-01')).thenReturn('{ not json');
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<LevelCorrupted>()),
        (_) => fail('expected Left(LevelCorrupted)'),
      );
    });

    test('should_return_LevelCorrupted_when_cached_payload_is_not_a_json_object',
        () async {
      // Arrange — red caída y la copia en caché es JSON VÁLIDO pero no un objeto
      // ('[1, 2]'). Antes de la guarda de forma en `_fromCache`, el `as Map`
      // lanzaba un TypeError crudo NO capturado que crasheaba a la persona que
      // llama; ahora debe emerger como LevelCorrupted (contrato §4.4).
      when(remote.fetchLevel('level-01'))
          .thenThrow(_dioError(type: DioExceptionType.connectionError));
      when(cache.readLevel('level-01')).thenReturn('[1, 2]');
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<LevelCorrupted>()),
        (_) => fail('expected Left(LevelCorrupted)'),
      );
    });

    test('should_return_LevelUnavailable_when_network_fails_and_no_cache',
        () async {
      // Arrange — red caída y sin copia en caché.
      when(remote.fetchLevel('level-01'))
          .thenThrow(_dioError(type: DioExceptionType.connectionError));
      when(cache.readLevel('level-01')).thenReturn(null);
      // Act
      final result = await repo.getLevel(LevelId('level-01'));
      // Assert
      expect(result, const Left<LevelFailure, Level>(LevelUnavailable()));
    });
  });

  group('listLevelIds', () {
    test('should_return_ids_and_write_through_when_network_succeeds', () async {
      // Arrange
      when(remote.fetchLevelIds()).thenAnswer((_) async => [
            {'levelId': 'level-01'},
            {'levelId': 'level-02'},
          ]);
      // Act
      final result = await repo.listLevelIds();
      // Assert — el valor es un List crudo (no Equatable): compararlo por
      // elementos con fold, no con la igualdad por identidad de dartz.
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (ids) => expect(ids, [LevelId('level-01'), LevelId('level-02')]),
      );
      verify(cache.writeCatalog(['level-01', 'level-02'])).called(1);
    });

    test('should_return_cached_ids_when_network_fails_and_cache_hit', () async {
      // Arrange
      when(remote.fetchLevelIds())
          .thenThrow(_dioError(type: DioExceptionType.connectionError));
      when(cache.readCatalog()).thenReturn(['level-01', 'level-02']);
      // Act
      final result = await repo.listLevelIds();
      // Assert
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (ids) => expect(ids, [LevelId('level-01'), LevelId('level-02')]),
      );
    });

    test('should_return_LevelUnavailable_when_network_fails_and_no_cache',
        () async {
      // Arrange
      when(remote.fetchLevelIds())
          .thenThrow(_dioError(type: DioExceptionType.connectionError));
      when(cache.readCatalog()).thenReturn(null);
      // Act
      final result = await repo.listLevelIds();
      // Assert
      expect(
        result,
        const Left<LevelFailure, List<LevelId>>(LevelUnavailable()),
      );
    });

    test('should_return_LevelCorrupted_when_catalog_payload_is_malformed',
        () async {
      // Arrange — entradas del catálogo sin la clave `levelId`.
      when(remote.fetchLevelIds()).thenAnswer((_) async => [
            {'nope': 1},
          ]);
      // Act
      final result = await repo.listLevelIds();
      // Assert
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<LevelCorrupted>()),
        (_) => fail('expected Left(LevelCorrupted)'),
      );
    });
  });
}
