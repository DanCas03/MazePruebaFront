import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/board/value_objects/level_id.dart';
import '../../domain/leaderboard/entities/leaderboard_entry.dart';
import '../../domain/leaderboard/entities/score_entry.dart';
import '../../domain/leaderboard/value_objects/canonical_result.dart';
import '../state/game_controller.dart';
import '../state/game_state.dart';
import '../use_cases/get_leaderboard_use_case.dart';
import '../use_cases/submit_score_use_case.dart';
import 'progress_providers.dart';

/// Se compone en main (DIP); la fábrica por defecto falla para no acoplar a
/// impls concretas antes de que existan.
final submitScoreUseCaseProvider = Provider<SubmitScoreUseCase>(
  (ref) => throw UnimplementedError(
    'submitScoreUseCaseProvider must be overridden with composed dependencies',
  ),
);

/// Resultado CANÓNICO (ADR 0006) de la última partida ganada enviada al back,
/// o `null` mientras no hay uno resuelto (partida en curso, envío en tránsito,
/// o el envío falló). La pantalla de victoria lo observa para reemplazar en
/// silencio el preview cliente por el dato definitivo — sin spinner (Q11):
/// el preview ya está pintado y el reemplazo es transparente.
final canonicalResultProvider = StateProvider<CanonicalResult?>((ref) => null);

/// Observer (GoF): escucha el estado de juego y, al ganar, dispara el envío del
/// score y reconcilia el resultado canónico. Desacopla `GameController` del
/// leaderboard. Se activa cuando `GameScreen` lo observa (`ref.watch`).
/// Deliberadamente NO es `autoDispose`: vive con el contenedor, para que el
/// envío fire-and-forget sobreviva a la navegación fuera de la pantalla de
/// victoria y no se pierda al cambiar de nivel.
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
        collisions: state.collisions,
      );
      // Nueva victoria: reinicia el canónico previo antes de que llegue el
      // nuevo (o de que el envío falle y se quede en preview).
      ref.read(canonicalResultProvider.notifier).state = null;
      // Fire-and-forget: el use case traga los errores; no `await` para no
      // bloquear la transición a la pantalla de victoria.
      unawaited(_submitAndReconcile(ref, useCase, entry));
    }
  });
});

/// Envía el score y, si el back responde, reconcilia el provider y re-registra
/// el progreso LOCAL con los valores CANÓNICOS. `RecordLevelCompletionUseCase`
/// ya hace merge best-of, así que volver a llamarlo con el canónico es
/// idempotente y seguro (front#58).
Future<void> _submitAndReconcile(
  Ref ref,
  SubmitScoreUseCase useCase,
  ScoreEntry entry,
) async {
  final canonical = await useCase.execute(entry);
  if (canonical == null) return;
  ref.read(canonicalResultProvider.notifier).state = canonical;
  final recordUseCase = ref.read(recordLevelCompletionUseCaseProvider);
  await recordUseCase.execute(
    entry.levelId,
    score: canonical.score.value,
    stars: canonical.stars.value,
  );
}

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
