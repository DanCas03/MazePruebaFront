import 'package:equatable/equatable.dart';

import 'level_id.dart';
import 'level_section.dart';

/// Entrada del Catálogo tal como la publica el back (`GET /levels`): el id opaco
/// del nivel y su [LevelSection]. Es el metadato mínimo de navegación/selección;
/// la definición jugable sigue siendo `Level`/`LevelBlueprint`.
///
/// Separa "qué niveles existen y a qué bloque pertenecen" (campaña vs temáticos)
/// de "cómo se agrupan por dificultad" (el Tier, que solo aplica a campaña y se
/// deriva de la POSICIÓN entre los niveles de campaña, nunca del id).
class CatalogEntry extends Equatable {
  final LevelId id;
  final LevelSection section;

  const CatalogEntry({required this.id, required this.section});

  @override
  List<Object?> get props => [id, section];
}
