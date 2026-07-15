/// Escalón de dificultad de la rampa curada (dominio puro). La curación agrupa
/// los niveles oficiales en 5 Tiers (3 niveles cada uno); el Tier es la unidad
/// de agrupación visual y la unidad de gating (un Tier se desbloquea al
/// completar el anterior). No confundir con la Rampa de producción
/// (`tool/level_production/`), que traduce un tier a dimensiones concretas del
/// tablero al fabricar candidatos.
enum Tier {
  one,
  two,
  three,
  four,
  five;

  /// Rango humano 1..5 (el `index` del enum es 0-based).
  int get rank => index + 1;

  /// El Tier inmediatamente anterior por dificultad, o `null` para el primero
  /// (que siempre está desbloqueado). Base de la regla de gating secuencial.
  Tier? get previous => index == 0 ? null : Tier.values[index - 1];

  /// Cuántos niveles agrupa cada Tier en la curación (3 por Tier).
  static const int levelsPerTier = 3;

  /// Deriva el Tier de un número de nivel 1-based (1..3 → Tier.one, 4..6 →
  /// Tier.two, …). Satura al último Tier para números por encima de la rampa,
  /// de modo que el catálogo pueda crecer sin romper el mapeo.
  factory Tier.forLevelNumber(int levelNumber) {
    final n = levelNumber < 1 ? 1 : levelNumber;
    final idx = ((n - 1) ~/ levelsPerTier).clamp(0, Tier.values.length - 1);
    return Tier.values[idx];
  }
}
