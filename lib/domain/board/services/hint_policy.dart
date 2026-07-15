import '../value_objects/level_id.dart';

/// Política de elegibilidad de la pista auto-resolutora (#32): en CAMPAÑA solo
/// los niveles difíciles (número ≥ [minEligibleLevel]) ofrecen la demo de la
/// solución del servidor. Fuente única del umbral, compartida por la UI
/// (renderizado del botón de la bombilla) y el controlador (guarda defensiva
/// antes del fetch).
class HintPolicy {
  const HintPolicy();

  /// Primer nivel de campaña con pista disponible. Por debajo, la mecánica se
  /// aprende sin ayuda; a partir de aquí la demo del servidor es un salvavidas
  /// opcional.
  static const int minEligibleLevel = 7;

  /// Elegibilidad consciente de sección (front#67). Los niveles TEMÁTICOS son
  /// SIEMPRE elegibles: tienen Solución servible y no forman parte de la curva
  /// de aprendizaje por Tier. Además su id (`t-…`) no es numérico, así que
  /// `LevelId.number` cae a 1 (wart conocido) y el umbral de campaña los
  /// excluiría por accidente; el flag [themed] evita depender de ese parseo.
  bool isEligible(LevelId id, {bool themed = false}) =>
      themed || id.number >= minEligibleLevel;
}
