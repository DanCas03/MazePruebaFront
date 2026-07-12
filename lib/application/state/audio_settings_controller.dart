import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/i_audio_service.dart';
import '../audio/silent_audio_service.dart';
import '../use_cases/toggle_music_use_case.dart';
import '../use_cases/toggle_sfx_use_case.dart';
import 'audio_settings_state.dart';

/// Fachada reactiva del estado de muteo de audio para la pantalla de ajustes.
///
/// La fachada [IAudioService] no es observable (getters `bool`); este Notifier
/// publica un [AudioSettingsState] inicializado desde ella y lo mantiene
/// sincronizado tras cada toggle. La mutacion (y su persistencia) se delega en
/// los casos de uso [ToggleMusicUseCase] / [ToggleSfxUseCase].
///
/// La dependencia se inyecta por constructor (DIP): la capa `application` NUNCA
/// importa `presentation`/`infrastructure`. El default del provider usa el Null
/// Object [SilentAudioService] (capa application) para que los tests de widget y
/// las capas sin audio compuesto funcionen; `main` lo sobreescribe con el
/// AudioService real via `overrideWith`, igual que `gameControllerProvider`.
final audioSettingsControllerProvider =
    NotifierProvider<AudioSettingsController, AudioSettingsState>(
  () => AudioSettingsController(const SilentAudioService()),
);

class AudioSettingsController extends Notifier<AudioSettingsState> {
  AudioSettingsController(this._audio);

  final IAudioService _audio;

  @override
  AudioSettingsState build() => AudioSettingsState(
        musicMuted: _audio.musicMuted,
        sfxMuted: _audio.sfxMuted,
      );

  Future<void> toggleMusic() async {
    final muted = await ToggleMusicUseCase(_audio).execute();
    state = state.copyWith(musicMuted: muted);
  }

  Future<void> toggleSfx() async {
    final muted = await ToggleSfxUseCase(_audio).execute();
    state = state.copyWith(sfxMuted: muted);
  }
}
