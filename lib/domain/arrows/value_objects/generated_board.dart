import 'package:equatable/equatable.dart';

import '../../core/exceptions/invalid_generator_config_exception.dart';
import '../entities/arrow_board.dart';
import 'generator_config.dart';

/// GeneratedBoard (Tablero generado, glosario front#36): un [ArrowBoard]
/// construido localmente con parámetros del jugador — efímero, sin puntuar,
/// NO persistido y reproducible vía seed dentro de la misma versión de la app.
/// A diferencia de un `Level`, no tiene `LevelId` ni pertenece a la campaña.
class GeneratedBoard extends Equatable {
  final ArrowBoard board;

  /// Config EFECTIVA de la generación: siempre lleva la seed usada, se haya
  /// fijado por el jugador o generado por el caso de uso.
  final GeneratorConfig config;

  GeneratedBoard({required this.board, required this.config}) {
    if (config.seed == null) {
      throw const InvalidGeneratorConfigException(
        'GeneratedBoard requires an effective config with a seed',
      );
    }
  }

  /// Seed con la que se generó el tablero (reproducibilidad: misma seed +
  /// misma config ⇒ tablero idéntico).
  int get seed => config.seed!;

  @override
  List<Object?> get props => [board, config];
}
