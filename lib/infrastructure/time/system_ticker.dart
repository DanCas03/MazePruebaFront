import 'dart:async';

import '../../domain/game_core/services/i_ticker.dart';

/// Impl real del puerto [ITicker] usando el reloj del sistema. Emite un valor
/// por segundo con la cuenta atrás: `seconds - 1`, `seconds - 2`, …, `0`, y
/// completa. Única clase de tiempo que la app compone en el composition root
/// (main.dart); la `application` solo conoce la abstracción (DIP).
class SystemTicker implements ITicker {
  const SystemTicker();

  @override
  Stream<int> countdown({required int seconds}) {
    if (seconds <= 0) return const Stream.empty();
    return Stream<int>.periodic(
      const Duration(seconds: 1),
      (tick) => seconds - tick - 1,
    ).take(seconds);
  }
}
