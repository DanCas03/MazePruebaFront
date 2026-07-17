import 'dart:math' as math;

/// Ritmo de reproducción del auto-solver (#102, evolución de #32). Antes el
/// paso entre flechas era una `Duration` CONSTANTE (420 ms) sin importar el
/// tamaño del tablero; en los niveles grandes de campaña (T5 ronda ~120-180
/// flechas, ver `tool/level_production/ramp.dart`) ver la demo completa a ese
/// ritmo se sentía eterno. Aquí el delay por paso DECRECE con el número de
/// flechas de la Solución — tableros chicos se reproducen deliberados,
/// grandes no arrastran.
///
/// PISO: el delay nunca baja de la duración de la animación de salida vigente
/// para ese tamaño ([exitDurationFor]) — si el paso empezara antes, la
/// siguiente flecha se remontaría a mitad del slide de la anterior. Para los
/// tableros más grandes, ese piso se permite bajar COMPRIMIENDO la propia
/// animación de salida en este modo (ver `ExitingArrowWidget.duration`, cuyo
/// valor por defecto de 360 ms —gameplay normal— no cambia); así el piso
/// puede acompañar la aceleración sin sacrificar la legibilidad del slide de
/// cada flecha en los tableros chicos.
class AutoSolvePacing {
  const AutoSolvePacing._();

  // Extremos de la curva, calibrados contra la rampa de producción: T1 (~7
  // flechas) cae en o bajo `_smallCount` → ritmo deliberado tope; T5 (~118-180
  // flechas) cae en o sobre `_largeCount` → ritmo rápido tope.
  static const int _smallCount = 8;
  static const int _largeCount = 120;

  static const Duration _maxStepDelay = Duration(milliseconds: 420); // = el viejo hintStepDelay de #32
  static const Duration _minStepDelay = Duration(milliseconds: 90);

  static const Duration _maxExitDuration = Duration(milliseconds: 360); // = ExitingArrowWidget por defecto
  static const Duration _minExitDuration = Duration(milliseconds: 120);

  /// Progreso 0..1 de [arrowCount] entre el extremo chico y el grande de
  /// referencia, clamped en los bordes (mesetas deliberadas/rápidas).
  static double _progress(int arrowCount) {
    if (arrowCount <= _smallCount) return 0;
    if (arrowCount >= _largeCount) return 1;
    return (arrowCount - _smallCount) / (_largeCount - _smallCount);
  }

  static int _lerpMs(Duration from, Duration to, double t) {
    final a = from.inMilliseconds;
    final b = to.inMilliseconds;
    return (a + (b - a) * t).round();
  }

  /// Duración de la animación de salida a usar DURANTE la demo del
  /// auto-solver para una Solución de [arrowCount] flechas: la misma de
  /// siempre (360 ms) en tableros chicos, comprimida linealmente hasta 120 ms
  /// en los más grandes. El gameplay normal (fuera de esta demo) nunca ve
  /// este valor — sigue fijo en 360 ms.
  static Duration exitDurationFor(int arrowCount) => Duration(
        milliseconds:
            _lerpMs(_maxExitDuration, _minExitDuration, _progress(arrowCount)),
      );

  /// Delay entre pasos para una Solución de [arrowCount] flechas: decrece con
  /// el conteo, nunca por debajo de [exitDurationFor] (el piso). `static` (no
  /// instancia) para poder usarla como valor por defecto de un parámetro —
  /// solo un tear-off de función estática es una expresión constante.
  static Duration stepDelayFor(int arrowCount) {
    final target = _lerpMs(_maxStepDelay, _minStepDelay, _progress(arrowCount));
    final floor = exitDurationFor(arrowCount).inMilliseconds;
    return Duration(milliseconds: math.max(target, floor));
  }
}
