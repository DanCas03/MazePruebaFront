/// Sección del catálogo a la que pertenece un nivel (dominio puro, sin Flutter).
///
/// - [campaign]: nivel de la campaña curada, con gating por Tier y "siguiente
///   nivel" (adyacencia en el orden de juego).
/// - [themed]: nivel temático real (puntúa y persiste como cualquiera) pero SIN
///   gating por Tier ni adyacencia de "siguiente nivel"; vive en su propio
///   bloque de la pantalla de selección.
enum LevelSection {
  campaign,
  themed;

  /// Traduce el valor del wire (`section`) a la sección. Aditivo y tolerante:
  /// solo el literal exacto `"themed"` es temático; ausente (`null`),
  /// `"campaign"` o cualquier valor desconocido degradan a [campaign]. Así el
  /// back puede introducir secciones nuevas sin romper clientes viejos.
  static LevelSection fromWire(String? raw) =>
      raw == 'themed' ? LevelSection.themed : LevelSection.campaign;
}
