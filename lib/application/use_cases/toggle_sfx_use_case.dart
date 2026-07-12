import '../audio/i_audio_service.dart';

/// Caso de uso: alterna el muteo de los efectos de sonido (SFX), independiente
/// de la musica. Delega en la fachada de audio (que persiste el flag) y devuelve
/// el nuevo estado de muteo para el controller reactivo.
class ToggleSfxUseCase {
  const ToggleSfxUseCase(this._audio);

  final IAudioService _audio;

  Future<bool> execute() async {
    final next = !_audio.sfxMuted;
    await _audio.setSfxMuted(next);
    return next;
  }
}
