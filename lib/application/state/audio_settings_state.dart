import 'package:flutter/foundation.dart';

/// Estado reactivo de los muteos de audio para la UI de ajustes (front#19).
///
/// La fachada [IAudioService] expone getters `bool` NO observables; este value
/// object inmutable es lo que el [AudioSettingsController] publica para que la
/// pantalla se reconstruya al alternar cada control. Solo cubre musica y SFX
/// (los dos controles independientes de la pantalla); el master vive en la
/// fachada pero no se expone en esta UI.
@immutable
class AudioSettingsState {
  const AudioSettingsState({
    required this.musicMuted,
    required this.sfxMuted,
  });

  final bool musicMuted;
  final bool sfxMuted;

  AudioSettingsState copyWith({bool? musicMuted, bool? sfxMuted}) =>
      AudioSettingsState(
        musicMuted: musicMuted ?? this.musicMuted,
        sfxMuted: sfxMuted ?? this.sfxMuted,
      );

  @override
  bool operator ==(Object other) =>
      other is AudioSettingsState &&
      other.musicMuted == musicMuted &&
      other.sfxMuted == sfxMuted;

  @override
  int get hashCode => Object.hash(musicMuted, sfxMuted);
}
