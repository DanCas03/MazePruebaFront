import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../domain/leaderboard/entities/leaderboard_entry.dart';
import '../../domain/leaderboard/entities/score_entry.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import '../use_cases/get_leaderboard_use_case.dart';
import '../use_cases/submit_score_use_case.dart';

/// Se compone en main (DIP); la fábrica por defecto falla para no acoplar a
/// impls concretas antes de que existan.
final submitScoreUseCaseProvider = Provider<SubmitScoreUseCase>(
  (ref) => throw UnimplementedError(
    'submitScoreUseCaseProvider must be overridden with composed dependencies',
  ),
);

/// Observer (GoF): escucha el estado de juego y, al ganar, dispara el envío del
/// score fire-and-forget. Desacopla `GameController` del leaderboard. Se activa
/// cuando `GameScreen` lo observa (`ref.watch`). Deliberadamente NO es
/// `autoDispose`: vive con el contenedor, para que el envío fire-and-forget
/// sobreviva a la navegación fuera de la pantalla de victoria y no se pierda
/// al cambiar de nivel.
final scoreSubmissionObserverProvider = Provider<void>((ref) {
  final useCase = ref.watch(submitScoreUseCaseProvider);
  ref.listen<AsyncValue<GameState>>(gameControllerProvider, (previous, next) {
    final state = next.valueOrNull;
    // front#98: dispara SOLO en el BORDE de transición hacia GameWon, no ante
    // "el estado ES GameWon". Al cargar el siguiente nivel, el estado de carga
    // RETIENE el valor GameWon anterior (Riverpod preserva el último dato en
    // AsyncLoading), así que sin la guarda de borde este listener re-enviaría el
    // score del nivel ya ganado en CADA carga posterior (POST duplicado).
    if (state is GameWon && previous?.valueOrNull is! GameWon) {
      final entry = ScoreEntry(
        levelId: state.levelId,
        score: state.score,
        stars: state.stars,
        moves: state.moves,
        timeSeconds: state.timeSeconds,
      );
      // Fire-and-forget: el use case traga los errores; no `await` para no
      // bloquear la transición a la pantalla de victoria.
      unawaited(useCase.execute(entry));
    }
  });
});

/// front#17 (lado lectura). Se compone en main con el Dio firmado (DIP); el
/// default falla para no acoplar a impls concretas antes de que existan.
final getLeaderboardUseCaseProvider = Provider<GetLeaderboardUseCase>(
  (ref) => throw UnimplementedError(
    'getLeaderboardUseCaseProvider must be overridden with composed dependencies',
  ),
);

/// Expone el ranking por nivel a la UI con los tres estados que pide el criterio
/// de aceptación (carga/datos/error) vía `AsyncValue`. `family` por `levelId`
/// (String, para clave estable); `autoDispose` para recargar al reabrir la
/// pantalla y no cachear un ranking obsoleto.
final leaderboardProvider =
    FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>(
  (ref, levelId) {
    final useCase = ref.watch(getLeaderboardUseCaseProvider);
    return useCase.execute(LevelId(levelId));
  },
);
