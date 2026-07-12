import 'i_locale_store.dart';

/// Null Object (GoF) de [ILocaleStore]: no persiste nada (idioma en memoria).
///
/// Vive en `application/` — como [SilentAudioService] — para poder ser el valor
/// por defecto del `localeControllerProvider` sin que la capa application
/// importe `infrastructure`. Permite que la app y los tests de widget rendericen
/// sin abrir Hive; `main` inyecta la [HiveLocaleStore] real.
class InMemoryLocaleStore implements ILocaleStore {
  InMemoryLocaleStore([this._code]);

  String? _code;

  @override
  String? get languageCode => _code;

  @override
  Future<void> setLanguageCode(String? code) async => _code = code;
}
