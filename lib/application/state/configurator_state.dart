import 'package:equatable/equatable.dart';

import '../../domain/arrows/value_objects/aspect_band.dart';
import '../../domain/arrows/value_objects/difficulty.dart';
import '../../domain/arrows/value_objects/generator_config.dart';

/// Estado del formulario del configurador de tableros generados (front#37).
///
/// La intención del jugador (tamaño/dificultad/contrarreloj/semilla) es lo
/// único editable; los parámetros internos del generador los DERIVA
/// [GeneratorConfig] a partir de esto. Inmutable + [copyWith] al estilo del
/// resto de estados de la app.
class ConfiguratorState extends Equatable {
  final int cols;
  final int rows;
  final Difficulty difficulty;
  final bool timed;

  /// Texto crudo de la semilla opcional. Vacío ⇒ semilla aleatoria (la elige el
  /// caso de uso). No vacío ⇒ debe ser un entero para que el formulario sea
  /// válido (ver [isSeedValid]).
  final String seedText;

  const ConfiguratorState({
    this.cols = 6,
    this.rows = 10,
    this.difficulty = Difficulty.medium,
    this.timed = false,
    this.seedText = '',
  });

  /// La semilla es válida si está vacía (aleatoria) o parsea a entero.
  bool get isSeedValid => seedText.isEmpty || int.tryParse(seedText) != null;

  /// Los selectores de columnas/filas acotan cada dimensión por separado al
  /// rango jugable, pero pueden combinarse en una proporción fuera de la banda
  /// portrait (front#101, [AspectBand]) — p. ej. subir columnas sin subir filas
  /// a la par. Se expone por separado de [isValid] para que la UI explique
  /// POR QUÉ "Jugar" está deshabilitado en vez de bloquearlo en silencio.
  bool get isAspectValid => AspectBand.contains(cols, rows);

  /// El formulario es jugable si dimensiones, aspecto y semilla son válidos.
  bool get isValid =>
      isSeedValid &&
      cols >= GeneratorConfig.minDimension &&
      cols <= GeneratorConfig.maxDimension &&
      rows >= GeneratorConfig.minDimension &&
      rows <= GeneratorConfig.maxDimension &&
      isAspectValid;

  /// Semilla efectiva a pasar al caso de uso: null (aleatoria) si el texto está
  /// vacío. Solo debe leerse cuando [isValid] es true.
  int? get seed => seedText.isEmpty ? null : int.tryParse(seedText);

  /// Construye la [GeneratorConfig] de dominio desde la intención del jugador.
  /// Solo debe invocarse con [isValid] == true.
  GeneratorConfig toConfig() => GeneratorConfig.create(
        cols: cols,
        rows: rows,
        difficulty: difficulty,
        timed: timed,
        seed: seed,
      );

  ConfiguratorState copyWith({
    int? cols,
    int? rows,
    Difficulty? difficulty,
    bool? timed,
    String? seedText,
  }) =>
      ConfiguratorState(
        cols: cols ?? this.cols,
        rows: rows ?? this.rows,
        difficulty: difficulty ?? this.difficulty,
        timed: timed ?? this.timed,
        seedText: seedText ?? this.seedText,
      );

  @override
  List<Object?> get props => [cols, rows, difficulty, timed, seedText];
}
