import 'package:equatable/equatable.dart';

import '../value_objects/level_id.dart';

/// Fallos esperados al pedir la Solución de un nivel (#32), como jerarquía
/// sellada para que la app haga pattern matching exhaustivo (espejo de
/// [LevelFailure]). Equatable para comparar fallos con datos en los tests.
/// `message` es para logging/diagnóstico; la UI mapea la pista fallida a un
/// único snackbar localizado (la pista es una comodidad, no una ruta bloqueante).
sealed class SolutionFailure extends Equatable {
  const SolutionFailure();
  String get message;
}

/// Red caída, timeout (connect/receive/send) o error de servidor: la solución no
/// puede obtenerse ahora. Sin caché (la pista es on-demand), no hay fallback.
class SolutionUnavailable extends SolutionFailure {
  const SolutionUnavailable();

  @override
  String get message => 'Solution unavailable';

  @override
  List<Object?> get props => const [];
}

/// 404 del back: el nivel (y por tanto su solución) no existe.
class SolutionNotFound extends SolutionFailure {
  final LevelId id;
  const SolutionNotFound(this.id);

  @override
  String get message => 'Solution not found: ${id.value}';

  @override
  List<Object?> get props => [id];
}

/// 422 del back: el nivel existe pero no tiene solución (invariante de
/// solubilidad rota; el back se niega a servir una demo imposible).
class SolutionUnsolvable extends SolutionFailure {
  final LevelId id;
  const SolutionUnsolvable(this.id);

  @override
  String get message => 'Level has no solution: ${id.value}';

  @override
  List<Object?> get props => [id];
}

/// El JSON de la solución no cumple el wire contract (`solution: string[]`):
/// dato corrupto.
class SolutionCorrupted extends SolutionFailure {
  final String reason;
  const SolutionCorrupted(this.reason);

  @override
  String get message => 'Solution data corrupted: $reason';

  @override
  List<Object?> get props => [reason];
}
