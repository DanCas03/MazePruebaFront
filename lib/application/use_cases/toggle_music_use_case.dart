import '../audio/i_audio_service.dart';

/// Caso de uso: alterna el muteo de la musica de fondo (BGM), independiente de
/// los SFX. Encapsula la mutacion sobre la fachada de audio (que ademas la
/// persiste). Devuelve el nuevo estado de muteo para que el controller reactivo
/// actualice su estado sin releer la fachada.
class ToggleMusicUseCase {
  const ToggleMusicUseCase(this._audio);

  final IAudioService _audio;

  Future<bool> execute() async {
    final next = !_audio.musicMuted;
    await _audio.setMusicMuted(next);
    return next;
  }
}
