import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/leaderboard/entities/score_entry.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
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
    if (state is GameWon) {
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
