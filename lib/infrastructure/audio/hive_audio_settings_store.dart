import 'package:hive_ce/hive.dart';

import 'i_audio_settings_store.dart';

/// Persistencia del estado de mute en un box Hive SIN tipar (tres booleanos).
///
/// Patron DataSource (Petros): encapsula el acceso directo a Hive; la fachada
/// depende de [IAudioSettingsStore], no de Hive. Al ser valores primitivos no
/// requiere un adapter generado ni tocar `hive_registrar.g.dart`. El box se
/// abre en el composition root (`main`) y se inyecta aqui.
class HiveAudioSettingsStore implements IAudioSettingsStore {
  HiveAudioSettingsStore(this._box);

  final Box _box;

  /// Nombre del box; lo usa `main` para abrirlo antes de inyectarlo.
  static const String boxName = 'audio_settings';

  static const String _kMaster = 'master_muted';
  static const String _kMusic = 'music_muted';
  static const String _kSfx = 'sfx_muted';

  @override
  bool get masterMuted => _box.get(_kMaster, defaultValue: false) as bool;

  @override
  bool get musicMuted => _box.get(_kMusic, defaultValue: false) as bool;

  @override
  bool get sfxMuted => _box.get(_kSfx, defaultValue: false) as bool;

  @override
  Future<void> setMasterMuted(bool value) => _box.put(_kMaster, value);

  @override
  Future<void> setMusicMuted(bool value) => _box.put(_kMusic, value);

  @override
  Future<void> setSfxMuted(bool value) => _box.put(_kSfx, value);
}
