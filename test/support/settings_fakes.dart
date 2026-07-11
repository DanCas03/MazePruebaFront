import 'package:flutter_arrow_maze/application/audio/i_audio_service.dart';
import 'package:flutter_arrow_maze/application/settings/i_locale_store.dart';

/// Fake mutable de [IAudioService] para los tests de front#19: captura el estado
/// de los tres muteos sin players ni Hive. Los tres flags son independientes.
class FakeAudioService implements IAudioService {
  FakeAudioService({
    this.masterMuted = false,
    this.musicMuted = false,
    this.sfxMuted = false,
  });

  @override
  bool masterMuted;
  @override
  bool musicMuted;
  @override
  bool sfxMuted;

  @override
  Future<void> setMasterMuted(bool muted) async => masterMuted = muted;
  @override
  Future<void> setMusicMuted(bool muted) async => musicMuted = muted;
  @override
  Future<void> setSfxMuted(bool muted) async => sfxMuted = muted;

  @override
  Future<void> init() async {}
  @override
  Future<void> play(GameSound sound) async {}
  @override
  Future<void> startMusic() async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> dispose() async {}
}

/// Fake de [ILocaleStore] en memoria que cuenta las escrituras, para verificar
/// la persistencia del idioma en los tests.
class FakeLocaleStore implements ILocaleStore {
  FakeLocaleStore([this._code]);

  String? _code;
  int writeCount = 0;

  @override
  String? get languageCode => _code;

  @override
  Future<void> setLanguageCode(String? code) async {
    _code = code;
    writeCount++;
  }
}
