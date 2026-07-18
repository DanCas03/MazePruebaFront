/// Sección del catálogo a la que pertenece un nivel (dominio puro, sin Flutter).
///
/// - [campaign]: nivel de la campaña curada, con gating por Tier y "siguiente
///   nivel" (adyacencia en el orden de juego).
/// - [themed]: nivel temático real (puntúa y persiste como cualquiera) pero SIN
///   gating por Tier ni adyacencia de "siguiente nivel"; vive en su propio
///   bloque de la pantalla de selección.
/// - [hex]: ficha libre del modo hexagonal (ADR-0007 D6), sin Tier ni gating,
///   en su propia colección. Es ORTOGONAL al espacio del nivel: un temático
///   sobre malla hex es `themed`, no `hex` — el `hex` es una superficie de
///   producto, no una geometría.
enum LevelSection {
  campaign,
  themed,
  hex;

  /// Traduce el valor del wire (`section`) a la sección. Aditivo y tolerante:
  /// sólo los literales exactos `"themed"` y `"hex"` cuentan; ausente (`null`),
  /// `"campaign"` o cualquier valor desconocido degradan a [campaign]. Así el
  /// back puede introducir secciones nuevas sin romper clientes viejos.
  static LevelSection fromWire(String? raw) => switch (raw) {
        'themed' => LevelSection.themed,
        'hex' => LevelSection.hex,
        _ => LevelSection.campaign,
      };
}
