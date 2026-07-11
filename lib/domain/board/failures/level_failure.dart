import 'package:equatable/equatable.dart';

import '../value_objects/level_id.dart';

/// Fallos esperados al cargar niveles remotos, como jerarquía sellada para que
/// la UI haga pattern matching exhaustivo (espejo de AuthFailure). Equatable
/// para comparar fallos con datos (id/reason) en los tests. `message` es para
/// logging/diagnóstico; la UI mapea cada caso a su copy localizada (l10n).
sealed class LevelFailure extends Equatable {
  const LevelFailure();
  String get message;
}

/// 404 del back: el nivel no existe. El back es autoridad sobre la existencia,
/// así que el repo no consulta la caché para este caso.
class LevelNotFound extends LevelFailure {
  final LevelId id;
  const LevelNotFound(this.id);

  @override
  String get message => 'Level not found: ${id.value}';

  @override
  List<Object?> get props => [id];
}

/// Fallo de red (o servidor) SIN copia en caché: el nivel no puede jugarse ahora.
class LevelUnavailable extends LevelFailure {
  const LevelUnavailable();

  @override
  String get message => 'Level unavailable offline';

  @override
  List<Object?> get props => const [];
}

/// El JSON (de red o de caché) no cumple el wire contract: dato corrupto.
class LevelCorrupted extends LevelFailure {
  final String reason;
  const LevelCorrupted(this.reason);

  @override
  String get message => 'Level data corrupted: $reason';

  @override
  List<Object?> get props => [reason];
}
