import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/i_locale_store.dart';
import '../settings/in_memory_locale_store.dart';
import '../use_cases/set_language_use_case.dart';

/// Fachada reactiva del idioma seleccionado (front#19). `null` = seguir el
/// locale del sistema operativo.
///
/// El [MaterialApp] observa este provider y fija su `locale`; al cambiarlo, el
/// arbol se reconstruye y cada `AppLocalizations.of(context)` se reevalua, de
/// modo que TODOS los textos se actualizan EN VIVO sin reiniciar la app. La
/// seleccion se persiste via [SetLanguageUseCase] y se restaura en `build`.
///
/// El store se inyecta por constructor (DIP): la capa `application` no importa
/// `presentation`/`infrastructure`. El default usa el Null Object
/// [InMemoryLocaleStore] (capa application) para que la app y los tests de
/// widget rendericen sin persistencia; `main` lo sobreescribe con la
/// [HiveLocaleStore] real via `overrideWith`.
final localeControllerProvider = NotifierProvider<LocaleController, Locale?>(
  () => LocaleController(InMemoryLocaleStore()),
);

class LocaleController extends Notifier<Locale?> {
  LocaleController(this._store);

  final ILocaleStore _store;

  @override
  Locale? build() {
    final code = _store.languageCode;
    return code == null ? null : Locale(code);
  }

  Future<void> setLanguage(Locale? locale) async {
    await SetLanguageUseCase(_store).execute(locale?.languageCode);
    state = locale;
  }
}
