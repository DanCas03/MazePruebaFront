import '../value_objects/level_id.dart';

/// Política de elegibilidad del auto-solver (#102, evolución de #32): TODO
/// nivel de campaña lo ofrece — el umbral por dificultad (antes número ≥ 7)
/// se retira porque la mecánica se aprende igual de bien con la opción
/// explícita de "resolver por mí" disponible desde el nivel 1, siempre detrás
/// de la advertencia de confirmación (la UI la exige antes de reproducir).
/// Fuente única compartida por la UI (qué control se pinta) y el controlador
/// (guarda defensiva antes del fetch).
class HintPolicy {
  const HintPolicy();

  /// Siempre elegible: campaña completa y temáticos (#102). El parámetro
  /// [themed] se conserva en la firma —documenta en el call site que los
  /// niveles temáticos pasan por aquí sin depender del parseo numérico del id
  /// (`t-…` cae a 1, wart conocido de [LevelId.number])— aunque ya no cambie
  /// el resultado.
  bool isEligible(LevelId id, {bool themed = false}) => true;
}
