import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/arrows/value_objects/difficulty.dart';
import '../../domain/arrows/value_objects/generator_config.dart';
import 'configurator_state.dart';

/// Controlador del formulario del configurador (front#37). Reactivo con
/// Riverpod: la UI observa [ConfiguratorState] y reconstruye el estado de
/// habilitación del botón "Jugar" (`isValid`) al vuelo. `autoDispose` para
/// resetear el formulario al salir del configurador y no arrastrar la elección
/// anterior a una nueva entrada.
///
/// Sin dependencias de infraestructura: el formulario es estado de presentación
/// puro — parte del cortafuegos de "cero persistencia" del flujo generado.
final configuratorControllerProvider =
    NotifierProvider.autoDispose<ConfiguratorController, ConfiguratorState>(
  ConfiguratorController.new,
);

class ConfiguratorController extends AutoDisposeNotifier<ConfiguratorState> {
  @override
  ConfiguratorState build() => const ConfiguratorState();

  /// Acota [cols] al rango jugable antes de guardar (defensa en profundidad:
  /// los selectores ya lo limitan, pero la regla vive en un solo sitio).
  void setCols(int cols) => state = state.copyWith(cols: _clampDim(cols));

  void setRows(int rows) => state = state.copyWith(rows: _clampDim(rows));

  /// Aplica un preset de tamaño (S/M/L/XL, front#66) en una sola transición:
  /// fija ambas dimensiones a la vez (acotadas al rango jugable).
  void setSize(int cols, int rows) =>
      state = state.copyWith(cols: _clampDim(cols), rows: _clampDim(rows));

  void setDifficulty(Difficulty difficulty) =>
      state = state.copyWith(difficulty: difficulty);

  void setTimed(bool timed) => state = state.copyWith(timed: timed);

  void setSeedText(String seedText) =>
      state = state.copyWith(seedText: seedText.trim());

  int _clampDim(int value) => value.clamp(
        GeneratorConfig.minDimension,
        GeneratorConfig.maxDimension,
      );
}
