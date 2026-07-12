import 'package:hive_ce/hive.dart';

import '../../application/settings/i_locale_store.dart';

/// Persistencia de la preferencia de idioma en un box Hive SIN tipar (front#19).
///
/// Patron DataSource: encapsula el acceso directo a Hive; la aplicacion depende
/// de [ILocaleStore], no de Hive. Al ser un valor primitivo (String) no requiere
/// adapter generado. El box se abre en el composition root (`main`) y se inyecta
/// aqui, igual que `HiveAudioSettingsStore` (front#5).
class HiveLocaleStore implements ILocaleStore {
  HiveLocaleStore(this._box);

  final Box _box;

  /// Nombre del box; lo usa `main` para abrirlo antes de inyectarlo.
  static const String boxName = 'app_settings';

  static const String _kLocale = 'locale';

  @override
  String? get languageCode => _box.get(_kLocale) as String?;

  @override
  Future<void> setLanguageCode(String? code) =>
      code == null ? _box.delete(_kLocale) : _box.put(_kLocale, code);
}
