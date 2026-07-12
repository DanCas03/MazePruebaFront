import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../core/aspects/i_logger_service.dart';
import '../../domain/board/entities/level.dart';
import '../../domain/board/failures/level_failure.dart';
import '../../domain/board/repositories/i_level_repository.dart';
import '../../domain/board/value_objects/level_id.dart';
import '../data_sources/local/level_cache_data_source.dart';
import '../data_sources/remote/level_remote_data_source.dart';
import '../serialization/level_json_decoder.dart';

/// Adapter del puerto ILevelRepository. Estrategia network-first con fallback a
/// caché: online siempre refetchea y hace write-through; offline (o error de
/// servidor no-404) sirve la copia cacheada. Aquí muere DioException; ninguna
/// capa superior conoce HTTP. Logging vía ILoggerService (AOP; nunca print).
class RemoteLevelRepository implements ILevelRepository {
  final LevelRemoteDataSource _remote;
  final LevelCacheDataSource _cache;
  final LevelJsonDecoder _decoder;
  final ILoggerService _logger;

  RemoteLevelRepository(this._remote, this._cache, this._decoder, this._logger);

  static const _ctx = 'RemoteLevelRepository';

  @override
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds() async {
    try {
      final raw = await _remote.fetchLevelIds();
      final ids = _parseIds(raw); // FormatException si el JSON es corrupto
      // Write-through best-effort: un fallo de Hive/IO no debe perder el catálogo
      // ya obtenido ni escapar como excepción no mapeada (contrato de fallos).
      try {
        await _cache.writeCatalog([for (final id in ids) id.value]);
      } catch (e) {
        _logger.warn('cache write-through failed for catalog: $e', _ctx);
      }
      return Right(ids);
    } on DioException {
      // Red/servidor: la copia en caché es el fallback (network-first).
      final cached = _cache.readCatalog();
      if (cached == null) {
        _logger.warn('catalog unavailable offline', _ctx);
        return const Left(LevelUnavailable());
      }
      try {
        final ids = [for (final v in cached) LevelId(v)];
        _logger.warn('serving cached catalog (offline)', _ctx);
        return Right(ids);
      } catch (err) {
        _logger.error('cached catalog corrupted', _ctx, err);
        return Left(LevelCorrupted('cached catalog: $err'));
      }
    } on FormatException catch (e) {
      _logger.error('catalog corrupted: ${e.message}', _ctx, e);
      return Left(LevelCorrupted(e.message));
    }
  }

  @override
  Future<Either<LevelFailure, Level>> getLevel(LevelId id) async {
    try {
      final raw = await _remote.fetchLevel(id.value);
      final level = _decoder.decode(raw); // FormatException si corrupto
      // Write-through best-effort: un fallo de Hive/IO no debe perder el nivel ya
      // obtenido ni escapar como excepción no mapeada (contrato de fallos).
      try {
        await _cache.writeLevel(id.value, jsonEncode(raw));
      } catch (e) {
        _logger.warn('cache write-through failed for ${id.value}: $e', _ctx);
      }
      return Right(level);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // El back es autoridad sobre la existencia: no se consulta la caché.
        return Left(LevelNotFound(id));
      }
      return _fromCache(id); // red/servidor no-404 → fallback a caché
    } on FormatException catch (e) {
      _logger.error(
          'level ${id.value} corrupted (network): ${e.message}', _ctx, e);
      return Left(LevelCorrupted(e.message));
    }
  }

  Either<LevelFailure, Level> _fromCache(LevelId id) {
    final raw = _cache.readLevel(id.value);
    if (raw == null) {
      _logger.warn('level ${id.value} unavailable offline', _ctx);
      return const Left(LevelUnavailable());
    }
    try {
      final decoded = jsonDecode(raw);
      // Guarda de forma: un JSON válido pero que no es objeto (p. ej. '[1,2]',
      // 'null', '42') haría fallar `as Map` con un TypeError NO capturado por el
      // `on FormatException` de abajo, escapando el contrato §4.4. Lo convertimos
      // en FormatException para que se mapee a LevelCorrupted como el resto.
      if (decoded is! Map) {
        throw const FormatException('cached level is not a JSON object');
      }
      final level = _decoder.decode(decoded.cast<String, Object?>());
      _logger.warn('serving cached level ${id.value} (offline)', _ctx);
      return Right(level);
    } on FormatException catch (e) {
      _logger.error('cached level ${id.value} corrupted: ${e.message}', _ctx, e);
      return Left(LevelCorrupted(e.message));
    }
  }

  List<LevelId> _parseIds(List<dynamic> raw) {
    try {
      return [
        for (final item in raw) LevelId((item as Map)['levelId'] as String),
      ];
    } catch (e) {
      throw FormatException('malformed catalog: $e');
    }
  }
}
