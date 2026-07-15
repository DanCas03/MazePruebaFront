import '../value_objects/catalog_entry.dart';
import '../value_objects/level_descriptor.dart';
import '../value_objects/level_id.dart';
import '../value_objects/level_progress.dart';
import '../value_objects/level_section.dart';
import '../value_objects/tier.dart';
import 'tier_gating.dart';

/// Resultado de resolver "qué sigue" tras ganar un nivel (dominio puro, sin
/// Flutter). Sealed para que el consumidor (la pantalla de victoria) cubra los
/// cuatro caminos de forma exhaustiva, sin un `null` ambiguo:
/// - [NextLevelUnlocked]: hay siguiente nivel de campaña y su Tier está abierto.
/// - [NextLevelLocked]: hay siguiente nivel, pero su Tier sigue bloqueado
///   (faltan niveles previos por completar) — el caso del bug #81.
/// - [CampaignComplete]: el nivel ganado era el último de la campaña.
/// - [NotInCampaign]: el nivel ganado es temático (sin adyacencia ni gating).
sealed class NextLevelOutcome {
  const NextLevelOutcome();
}

class NextLevelUnlocked extends NextLevelOutcome {
  final LevelId levelId;
  const NextLevelUnlocked(this.levelId);
}

class NextLevelLocked extends NextLevelOutcome {
  const NextLevelLocked();
}

class CampaignComplete extends NextLevelOutcome {
  const CampaignComplete();
}

class NotInCampaign extends NextLevelOutcome {
  const NotInCampaign();
}

/// Regla de progresión de campaña respetuosa del gating (dominio puro). Cierra el
/// bug #81: la pantalla de victoria ofrecía el "siguiente nivel" por pura
/// adyacencia del Catálogo, saltándose [TierGating]; aquí la decisión de qué
/// sigue —y si es jugable— vive en el dominio, no en la presentación.
///
/// El Tier de cada nivel de campaña se deriva de su POSICIÓN entre los niveles de
/// campaña (mismo criterio que `LevelSelectionController`), nunca del id opaco;
/// intercalar temáticos no desplaza los Tiers.
class CampaignProgression {
  final TierGating _gating;

  const CampaignProgression(this._gating);

  /// Resuelve la progresión tras ganar [currentId], dados el [catalog] completo
  /// y el [progress] persistido. El nivel recién ganado se cuenta como completado
  /// aunque su escritura sea fire-and-forget (carrera con la navegación a la
  /// victoria): así el gating no depende de que la persistencia ya haya corrido.
  NextLevelOutcome resolve(
    LevelId currentId,
    List<CatalogEntry> catalog,
    List<LevelProgress> progress,
  ) {
    // Solo la campaña tiene orden de "siguiente" y gating por Tier.
    final campaignIds = [
      for (final e in catalog)
        if (e.section == LevelSection.campaign) e.id,
    ];
    final index = campaignIds.indexWhere((id) => id == currentId);
    if (index < 0) return const NotInCampaign();
    if (index + 1 >= campaignIds.length) return const CampaignComplete();

    final nextId = campaignIds[index + 1];

    // Descriptores con Tier derivado de la posición 1-based dentro de campaña.
    final descriptors = [
      for (var i = 0; i < campaignIds.length; i++)
        LevelDescriptor(
          levelId: campaignIds[i],
          tier: Tier.forLevelNumber(i + 1),
        ),
    ];

    // El nivel actual cuenta como completado para evaluar el desbloqueo.
    final progressWithCurrent = [
      ...progress,
      LevelProgress(levelId: currentId, completed: true),
    ];

    final nextDescriptor = descriptors[index + 1];
    return _gating.isLevelUnlocked(nextDescriptor, descriptors, progressWithCurrent)
        ? NextLevelUnlocked(nextId)
        : const NextLevelLocked();
  }
}
