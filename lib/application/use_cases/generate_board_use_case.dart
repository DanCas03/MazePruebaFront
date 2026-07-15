import 'dart:math';

import 'package:flutter/foundation.dart' show compute;

import '../../core/aspects/i_logger_service.dart';
import '../../domain/arrows/entities/arrow_board.dart';
import '../../domain/arrows/services/i_level_generator.dart';
import '../../domain/arrows/value_objects/generated_board.dart';
import '../../domain/arrows/value_objects/generator_config.dart';

/// Fuente de seeds inyectable: aísla el único efecto no determinista del flujo
/// (elegir seed cuando el jugador no la fija) fuera de la lógica, para poder
/// fijarlo en tests y mantener `execute` puro dado su input.
typedef SeedSource = int Function();

/// Genera un tablero efímero con parámetros del jugador (front#36): deriva los
/// parámetros del generador desde [GeneratorConfig], completa la seed si falta
/// y devuelve el [GeneratedBoard] con la config efectiva. NO persiste nada
/// (ni Hive, ni Progress, ni leaderboards): un tablero generado se juega y se
/// descarta. La degradación con gracia del generador (menos flechas de las
/// pedidas) se acepta tal cual — el tablero sigue siendo soluble.
class GenerateBoardUseCase {
  final ILevelGenerator _generator;
  final ILoggerService _logger;
  final SeedSource _seedSource;

  GenerateBoardUseCase(
    this._generator,
    this._logger, {
    SeedSource? seedSource,
  }) : _seedSource = seedSource ?? _randomSeed;

  // 2^31 - 1 mantiene el seed en rango seguro también en web (dart2js).
  static int _randomSeed() => Random().nextInt(0x7fffffff);

  /// Umbral (en celdas) a partir del cual [executeAsync] descarga la generación
  /// a un isolate. ≈ preset L (25×25 = 625): por debajo (S/M) el coste es de
  /// pocos ms y el ida/vuelta del isolate no compensa; por encima (L/XL) un
  /// 50×50 denso tarda cientos de ms — bloquearía el hilo de UI (front#66).
  static const int isolateCellThreshold = 600;

  GeneratedBoard execute(GeneratorConfig config) {
    final effective = _withEffectiveSeed(config);
    final board = _generator.generate(
      cols: effective.cols,
      rows: effective.rows,
      arrowCount: effective.arrowCount,
      maxPathLen: effective.maxPathLen,
      seed: effective.seed,
    );
    _logGenerated(effective, board);
    return GeneratedBoard(board: board, config: effective);
  }

  /// Variante no bloqueante para tableros grandes (front#66): a partir de
  /// [isolateCellThreshold] celdas corre la generación en un isolate de fondo
  /// (`compute`) para no tirar frames durante la espera; por debajo genera en
  /// línea (idéntico a [execute]). En web `compute` degrada a síncrono (no hay
  /// isolates), pero el objetivo del criterio de aceptación es móvil.
  ///
  /// Determinista: misma seed ⇒ mismo tablero, corra en isolate o no.
  Future<GeneratedBoard> executeAsync(GeneratorConfig config) async {
    final effective = _withEffectiveSeed(config);
    final args = _GenerateArgs(
      generator: _generator,
      cols: effective.cols,
      rows: effective.rows,
      arrowCount: effective.arrowCount,
      maxPathLen: effective.maxPathLen,
      seed: effective.seed!,
    );
    final board = effective.cols * effective.rows >= isolateCellThreshold
        ? await compute(_generateBoardInIsolate, args)
        : _generateBoardInIsolate(args);
    _logGenerated(effective, board);
    return GeneratedBoard(board: board, config: effective);
  }

  GeneratorConfig _withEffectiveSeed(GeneratorConfig config) =>
      config.seed == null ? config.withSeed(_seedSource()) : config;

  void _logGenerated(GeneratorConfig effective, ArrowBoard board) {
    _logger.log(
      'Generated ${effective.cols}x${effective.rows} '
      '${effective.difficulty.name} board: '
      '${board.arrows.length}/${effective.arrowCount} arrows '
      '(seed=${effective.seed}, timeLimitSec=${effective.timeLimitSec})',
      'GenerateBoardUseCase',
    );
  }
}

/// Argumentos serializables para el entrypoint del isolate. Debe ser enviable
/// por `compute`: el [generator] de producción (`GraphBoardGenerator()` sin
/// logger) y valores primitivos lo son.
class _GenerateArgs {
  final ILevelGenerator generator;
  final int cols;
  final int rows;
  final int arrowCount;
  final int maxPathLen;
  final int seed;

  const _GenerateArgs({
    required this.generator,
    required this.cols,
    required this.rows,
    required this.arrowCount,
    required this.maxPathLen,
    required this.seed,
  });
}

/// Entrypoint del isolate (top-level, requisito de `compute`): invoca el puerto
/// [ILevelGenerator] con los parámetros ya derivados. Puro respecto a su input.
ArrowBoard _generateBoardInIsolate(_GenerateArgs a) => a.generator.generate(
      cols: a.cols,
      rows: a.rows,
      arrowCount: a.arrowCount,
      maxPathLen: a.maxPathLen,
      seed: a.seed,
    );
