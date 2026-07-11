import 'i_audio_service.dart';

/// Null Object (GoF) del puerto [IAudioService]: no reproduce nada.
///
/// Es el valor por defecto del `audioServiceProvider` en el composition root,
/// de modo que las capas y los tests de widget que no compongan el audio real
/// (que necesita un box Hive abierto y players nativos) sigan funcionando sin
/// ramas condicionales ni comprobaciones de null. `main` lo sustituye por el
/// `AudioService` real decorado.
class SilentAudioService implements IAudioService {
  const SilentAudioService();

  @override
  Future<void> init() async {}

  @override
  Future<void> play(GameSound sound) async {}

  @override
  Future<void> startMusic() async {}

  @override
  Future<void> stopMusic() async {}

  @override
  bool get masterMuted => false;

  @override
  bool get musicMuted => false;

  @override
  bool get sfxMuted => false;

  @override
  Future<void> setMasterMuted(bool muted) async {}

  @override
  Future<void> setMusicMuted(bool muted) async {}

  @override
  Future<void> setSfxMuted(bool muted) async {}

  @override
  Future<void> dispose() async {}
}
