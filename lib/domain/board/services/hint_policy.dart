import '../value_objects/level_id.dart';

/// Política de elegibilidad de la pista auto-resolutora (#32): solo los niveles
/// difíciles (número ≥ [minEligibleLevel]) ofrecen la demo de la solución del
/// servidor. Fuente única del umbral, compartida por la UI (renderizado del
/// botón de la bombilla) y el controlador (guarda defensiva antes del fetch).
class HintPolicy {
  const HintPolicy();

  /// Primer nivel con pista disponible. Por debajo, la mecánica se aprende sin
  /// ayuda; a partir de aquí la demo del servidor es un salvavidas opcional.
  static const int minEligibleLevel = 7;

  bool isEligible(LevelId id) => id.number >= minEligibleLevel;
}
