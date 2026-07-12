import 'package:equatable/equatable.dart';

import 'level_id.dart';
import 'tier.dart';

/// Entrada del catálogo de niveles: identifica un nivel jugable y a qué Tier
/// pertenece. Es metadato de navegación/selección, NO la definición jugable del
/// nivel (esa es `LevelBlueprint`/`Level`, que trae dimensiones y flechas).
///
/// Mantener el catálogo como una lista de descriptores hace que la pantalla de
/// selección sea agnóstica a la cantidad de niveles: escalar de 15 a 30+ es
/// ampliar la lista que sirve `ILevelCatalog`, sin tocar la UI.
class LevelDescriptor extends Equatable {
  final LevelId levelId;
  final Tier tier;

  const LevelDescriptor({required this.levelId, required this.tier});

  @override
  List<Object?> get props => [levelId, tier];
}
