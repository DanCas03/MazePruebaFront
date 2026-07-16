import 'package:equatable/equatable.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/aspect_band.dart';

import '../../core/exceptions/invalid_generator_config_exception.dart';
import 'difficulty.dart';

/// Parámetros con los que el jugador pide un tablero generado (front#36).
/// Value Object defensivo: solo se construye vía [GeneratorConfig.create],
/// que valida el rango jugable de dimensiones y lanza
/// [InvalidGeneratorConfigException] (fallo semántico de dominio) si no cumple.
/// Los parámetros del generador ([arrowCount], [maxPathLen], [timeLimitSec])
/// se DERIVAN del preset de [Difficulty] y del tamaño — el jugador elige
/// intención (tamaño/dificultad/timer), no números internos.
class GeneratorConfig extends Equatable {
  /// Rango jugable de dimensiones (inclusive). Ajustable en un solo lugar:
  /// por debajo de 4 no hay puzzle. El techo se elevó a 50 en front#66: con el
  /// viewport de zoom/pan (InteractiveViewer) los tableros grandes ya se leen y
  /// se juegan en móvil, así que la vieja cota de 10 (celdas ilegibles sin
  /// cámara) quedó obsoleta. 50×50 es el preset XL / final de campaña (ADR 0003).
  static const int minDimension = 4;
  static const int maxDimension = 50;

  /// Piso y techo de la cuenta atrás derivada, en segundos. El piso espeja el
  /// mínimo histórico de la campaña (30 s); el techo acota tableros grandes y
  /// fáciles para que el timer siga significando algo.
  static const int minTimeLimitSec = 30;
  static const int maxTimeLimitSec = 300;

  /// Mínimo de flechas para que el resultado sea un puzzle (mismo piso que la
  /// campaña). El máximo teórico es (celdas ~/ 2): cada flecha ocupa >= 2.
  static const int minArrowCount = 4;

  final int cols;
  final int rows;
  final Difficulty difficulty;

  /// true ⇒ el tablero lleva cuenta atrás derivada (ver [timeLimitSec]).
  final bool timed;

  /// Seed de generación. Opcional: si el jugador no la fija, el caso de uso
  /// la genera y la devuelve en la config efectiva (reproducibilidad).
  final int? seed;

  const GeneratorConfig._({
    required this.cols,
    required this.rows,
    required this.difficulty,
    required this.timed,
    required this.seed,
  });

  /// Único punto de creación: rechaza dimensiones fuera de
  /// [minDimension]–[maxDimension] con un fallo semántico de dominio.
  factory GeneratorConfig.create({
    required int cols,
    required int rows,
    required Difficulty difficulty,
    bool timed = false,
    int? seed,
  }) {
    _requireInRange('cols', cols);
    _requireInRange('rows', rows);
    // front#101: shapes must fall inside the app-wide portrait band so a
    // generated board fills a phone screen. Explicit user input is rejected
    // (defaults are snapped elsewhere via AspectBand.snapRowsForCols).
    if (!AspectBand.contains(cols, rows)) {
      throw InvalidGeneratorConfigException(
          'aspect cols:rows must be within [${AspectBand.minRatio}, '
          '${AspectBand.maxRatio}] (portrait 9:16), got ${cols}x$rows = '
          '${(cols / rows).toStringAsFixed(3)}');
    }
    return GeneratorConfig._(
      cols: cols,
      rows: rows,
      difficulty: difficulty,
      timed: timed,
      seed: seed,
    );
  }

  static void _requireInRange(String name, int value) {
    if (value < minDimension || value > maxDimension) {
      throw InvalidGeneratorConfigException(
        '$name must be between $minDimension and $maxDimension, got $value',
      );
    }
  }

  /// Cantidad de flechas derivada de la densidad del preset. Mismo cálculo que
  /// la campaña: celdas objetivo / largo medio de camino.
  int get arrowCount {
    final avgPathLen = (2 + difficulty.maxPathLen) / 2;
    return (cols * rows * difficulty.fillRatio / avgPathLen)
        .round()
        .clamp(minArrowCount, (cols * rows) ~/ 2);
  }

  /// Largo máximo de camino doblado que se pasa al generador.
  int get maxPathLen => difficulty.maxPathLen;

  /// Cuenta atrás derivada de dificultad y tamaño (segundos por celda del
  /// preset, acotada a [minTimeLimitSec]–[maxTimeLimitSec]), o `null` si el
  /// jugador no pidió timer.
  int? get timeLimitSec => timed
      ? (cols * rows * difficulty.secondsPerCell)
          .round()
          .clamp(minTimeLimitSec, maxTimeLimitSec)
      : null;

  /// Copia con la seed fijada (config efectiva del resultado). No re-valida:
  /// las dimensiones ya pasaron por [GeneratorConfig.create].
  GeneratorConfig withSeed(int seed) => GeneratorConfig._(
        cols: cols,
        rows: rows,
        difficulty: difficulty,
        timed: timed,
        seed: seed,
      );

  @override
  List<Object?> get props => [cols, rows, difficulty, timed, seed];
}
