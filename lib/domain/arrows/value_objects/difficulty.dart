/// Preset de dificultad que el jugador elige al generar un tablero (front#36).
/// Concentra las constantes documentadas del mapeo dificultad → densidad de
/// flechas, largo máximo de camino doblado y presupuesto de tiempo por celda.
/// La política de dificultad vive en el dominio en un solo lugar testeable; el
/// generador solo genera. (La curva de PRODUCCIÓN de la campaña es su análoga,
/// la Rampa en `tool/level_production/`.)
enum Difficulty {
  easy(fillRatio: 0.40, maxPathLen: 3, secondsPerCell: 3.0),
  medium(fillRatio: 0.55, maxPathLen: 6, secondsPerCell: 2.0),
  hard(fillRatio: 0.70, maxPathLen: 9, secondsPerCell: 1.5);

  /// Densidad de flechas: fracción de celdas del tablero que los cuerpos de
  /// flecha buscan ocupar (más densidad ⇒ más bloqueos entre flechas).
  final double fillRatio;

  /// Largo máximo (en celdas) de los caminos doblados que coloca el generador.
  /// Caminos más largos se enredan más entre sí y son más difíciles de leer.
  final int maxPathLen;

  /// Segundos de cuenta atrás concedidos por celda cuando el tablero lleva
  /// timer: a más dificultad, menos tiempo por celda.
  final double secondsPerCell;

  const Difficulty({
    required this.fillRatio,
    required this.maxPathLen,
    required this.secondsPerCell,
  });
}
