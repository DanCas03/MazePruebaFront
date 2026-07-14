import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/game_controller.dart';
import '../state/game_state.dart';
import '../use_cases/record_level_completion_use_case.dart';

/// Se compone en main (DIP); la fábrica por defecto falla para no acoplar a
/// impls concretas antes de que existan.
final recordLevelCompletionUseCaseProvider =
    Provider<RecordLevelCompletionUseCase>(
  (ref) => throw UnimplementedError(
    'recordLevelCompletionUseCaseProvider must be overridden with composed '
    'dependencies',
  ),
);

/// Observer (GoF): escucha el estado de juego y, al ganar, persiste el progreso
/// LOCAL del nivel (completado + best score/estrellas) fire-and-forget. Es el
/// productor que faltaba del bucle de progresión (front#58): sin él, las
/// estrellas del selector y el gating de tiers (front#20) no tenían fuente de
/// datos. Espeja `scoreSubmissionObserverProvider` (front#16) pero contra el
/// store local en vez del leaderboard remoto. Se activa cuando `GameScreen` lo
/// observa. Deliberadamente NO es `autoDispose`: vive con el contenedor para
/// que la escritura sobreviva a la navegación a la pantalla de victoria.
final levelCompletionObserverProvider = Provider<void>((ref) {
  final useCase = ref.watch(recordLevelCompletionUseCaseProvider);
  ref.listen<AsyncValue<GameState>>(gameControllerProvider, (previous, next) {
    final state = next.valueOrNull;
    if (state is GameWon) {
      // Fire-and-forget: el use case traga sus errores; no `await` para no
      // bloquear la transición a la pantalla de victoria.
      unawaited(useCase.execute(
        state.levelId,
        score: state.score.value,
        stars: state.stars.value,
      ));
    }
  });
});
