/// Puerto de persistencia de la preferencia de idioma (front#19).
///
/// La aplicacion define el puerto; la infraestructura lo implementa (Hive en la
/// app, en memoria en tests). La regla de dependencia CLEAN se preserva: el caso
/// de uso [SetLanguageUseCase] depende SOLO de esta abstraccion, nunca de Hive.
abstract interface class ILocaleStore {
  /// Codigo de idioma persistido ('es' / 'en') o `null` = seguir el locale del
  /// sistema operativo.
  String? get languageCode;

  /// Persiste el codigo elegido; `null` borra la preferencia (vuelve al SO).
  Future<void> setLanguageCode(String? code);
}
