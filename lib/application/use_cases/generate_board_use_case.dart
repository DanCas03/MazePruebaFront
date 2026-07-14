import 'dart:math';

import '../../core/aspects/i_logger_service.dart';
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

  GeneratedBoard execute(GeneratorConfig config) {
    final effective =
        config.seed == null ? config.withSeed(_seedSource()) : config;
    final board = _generator.generate(
      cols: effective.cols,
      rows: effective.rows,
      arrowCount: effective.arrowCount,
      maxPathLen: effective.maxPathLen,
      seed: effective.seed,
    );
    _logger.log(
      'Generated ${effective.cols}x${effective.rows} '
      '${effective.difficulty.name} board: '
      '${board.arrows.length}/${effective.arrowCount} arrows '
      '(seed=${effective.seed}, timeLimitSec=${effective.timeLimitSec})',
      'GenerateBoardUseCase',
    );
    return GeneratedBoard(board: board, config: effective);
  }
}
