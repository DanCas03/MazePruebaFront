import '../settings/i_locale_store.dart';

/// Caso de uso: fija (y persiste) la preferencia de idioma de la app.
///
/// El codigo `null` borra la preferencia: la app vuelve a seguir el locale del
/// sistema operativo. El refresco en vivo de los textos lo produce el
/// [LocaleController], que publica el nuevo locale al MaterialApp.
class SetLanguageUseCase {
  const SetLanguageUseCase(this._store);

  final ILocaleStore _store;

  Future<void> execute(String? languageCode) =>
      _store.setLanguageCode(languageCode);
}
