import 'package:audioplayers/audioplayers.dart';

import 'i_audio_backend.dart';

/// Adapter (GoF): adapta el package `audioplayers` al puerto [IAudioBackend],
/// aislando al resto de la app del API concreto del package.
///
/// Usa dos players: uno dedicado a la musica (bucle) y otro reutilizable de
/// baja latencia para los efectos puntuales. Los eventos de juego estan lo
/// bastante espaciados como para no necesitar un pool de SFX solapados.
class AudioplayersBackend implements IAudioBackend {
  AudioplayersBackend({AudioPlayer? sfxPlayer, AudioPlayer? musicPlayer})
      : _sfx = sfxPlayer ?? AudioPlayer(),
        _music = musicPlayer ?? AudioPlayer();

  final AudioPlayer _sfx;
  final AudioPlayer _music;

  @override
  Future<void> playSfx(String asset) async {
    // ReleaseMode.stop: al terminar libera el recurso; el proximo SFX reutiliza
    // el player. Reproducir de nuevo interrumpe el SFX anterior (aceptable).
    await _sfx.setReleaseMode(ReleaseMode.stop);
    await _sfx.play(AssetSource(asset));
  }

  @override
  Future<void> loopMusic(String asset) async {
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.play(AssetSource(asset));
  }

  @override
  Future<void> stopMusic() => _music.stop();

  @override
  Future<void> dispose() async {
    await _sfx.dispose();
    await _music.dispose();
  }
}
