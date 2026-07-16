import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/dependency_providers.dart';
import '../../domain/board/services/campaign_progression.dart';
import '../../domain/board/services/tier_gating.dart';
import '../../domain/board/value_objects/level_id.dart';
import 'level_catalog_provider.dart';

/// Fachada reactiva del "qué sigue" tras ganar [levelId] (front#81). Compone el
/// Catálogo (`levelCatalogProvider`) y el progreso local persistido
/// (`levelProgressRepositoryProvider`) y delega la decisión —incluido el
/// gating— al servicio de dominio `CampaignProgression`. La pantalla de victoria
/// consume esto en vez de calcular la adyacencia por su cuenta, de modo que
/// ninguna ruta ofrezca un nivel de un Tier bloqueado.
///
/// Es `family` por [LevelId] (el nivel recién ganado) y `autoDispose` para no
/// retener el cómputo entre victorias. No necesita override en `main`: se
/// autocompone leyendo providers que ya se sobreescriben allí (DIP transitiva).
final nextLevelOutcomeProvider =
    FutureProvider.autoDispose.family<NextLevelOutcome, LevelId>(
  (ref, levelId) async {
    final catalog = await ref.watch(levelCatalogProvider.future);
    final progress = await ref.watch(levelProgressRepositoryProvider).getAll();
    const progression = CampaignProgression(TierGating());
    return progression.resolve(levelId, catalog, progress);
  },
);
