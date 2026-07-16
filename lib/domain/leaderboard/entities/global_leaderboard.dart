import 'package:equatable/equatable.dart';

/// Fila del Leaderboard general (`GET /leaderboard`, ADR 0006): un jugador con
/// sus totales de campaña — suma del MEJOR score y las MEJORES estrellas por
/// nivel (los temáticos y los `GeneratedBoard` no suman). A diferencia del
/// ranking por nivel, el `rank` SÍ viaja en el cable: la fila propia (`me`)
/// puede quedar fuera del top y su posición no es derivable del índice.
/// Dart puro, igualdad por valor.
class GlobalLeaderboardEntry extends Equatable {
  final String username;
  final int totalScore;
  final int totalStars;
  final int rank;

  GlobalLeaderboardEntry({
    required this.username,
    required this.totalScore,
    required this.totalStars,
    required this.rank,
  }) {
    // Invariantes validadas en runtime (no `assert`, que se elimina en
    // release; coherente con el resto de entidades de leaderboard).
    if (rank < 1) {
      throw ArgumentError('rank must be >= 1');
    }
    if (totalScore < 0 || totalStars < 0) {
      throw ArgumentError('totals must not be negative');
    }
  }

  @override
  List<Object?> get props => [username, totalScore, totalStars, rank];
}

/// Lectura completa del ranking general: el top-N que publica el back más la
/// fila propia del jugador autenticado (`me`), que es `null` mientras no haya
/// enviado ningún score de campaña ("sin clasificar").
class GlobalLeaderboard extends Equatable {
  final List<GlobalLeaderboardEntry> top;
  final GlobalLeaderboardEntry? me;

  GlobalLeaderboard({required List<GlobalLeaderboardEntry> top, this.me})
      : top = List.unmodifiable(top);

  /// La fila propia está ya visible dentro del top (no necesita anclarse aparte).
  bool get meIsInTop => me != null && me!.rank <= top.length;

  @override
  List<Object?> get props => [top, me];
}
