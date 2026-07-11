/// Puerto de persistencia del estado de mute del audio.
///
/// Separa la fachada [AudioService] del mecanismo de almacenamiento concreto
/// (Hive): en tests se mockea este puerto para verificar que un toggle persiste
/// sin tocar disco. Los tres flags son independientes (master / musica / SFX).
abstract interface class IAudioSettingsStore {
  bool get masterMuted;
  bool get musicMuted;
  bool get sfxMuted;

  Future<void> setMasterMuted(bool value);
  Future<void> setMusicMuted(bool value);
  Future<void> setSfxMuted(bool value);
}
