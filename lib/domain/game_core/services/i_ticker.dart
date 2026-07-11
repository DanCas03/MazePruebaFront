/// Puerto (DIP) de un reloj de cuenta atrás inyectable. La `application` depende
/// de esta abstracción; la impl real (`Stream.periodic`) vive en
/// `infrastructure/`, y los tests inyectan un reloj falso controlado a mano para
/// evitar fragilidad temporal (ADR 0001, decisión 6).
abstract interface class ITicker {
  /// Emite los segundos restantes, de [seconds] - 1 hasta 0 inclusive, uno por
  /// segundo. El 0 final es la señal de agotamiento (timeout → `GameLost`).
  Stream<int> countdown({required int seconds});

  /// Emite el tiempo transcurrido en segundos: 1, 2, 3, …, uno por segundo y
  /// sin cota. Alimenta el `timeSeconds` del score en TODOS los niveles
  /// (front#16), también los que no tienen límite de tiempo.
  Stream<int> elapsed();
}

/// Null Object (GoF): reloj inerte que nunca emite. Sirve como valor por defecto
/// del `GameController` cuando no se inyecta un reloj real (tests que no ejercen
/// el tiempo, niveles sin límite), evitando acoplar la `application` a la
/// infraestructura y sin necesidad de comprobar `null` en cada uso.
class NullTicker implements ITicker {
  const NullTicker();

  @override
  Stream<int> countdown({required int seconds}) => const Stream.empty();

  @override
  Stream<int> elapsed() => const Stream.empty();
}
