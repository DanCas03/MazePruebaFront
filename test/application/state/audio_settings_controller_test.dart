import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/audio_settings_controller.dart';

import '../../support/settings_fakes.dart';

/// Compone el controller con un [FakeAudioService] inyectado por constructor,
/// igual que hace `main` con el AudioService real (DIP).
ProviderContainer _containerWith(FakeAudioService audio) {
  final container = ProviderContainer(
    overrides: [
      audioSettingsControllerProvider
          .overrideWith(() => AudioSettingsController(audio)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('AudioSettingsController', () {
    test('should_expose_facade_state_when_built', () {
      // Arrange
      final audio = FakeAudioService(musicMuted: true, sfxMuted: false);
      final container = _containerWith(audio);

      // Act
      final state = container.read(audioSettingsControllerProvider);

      // Assert
      expect(state.musicMuted, isTrue);
      expect(state.sfxMuted, isFalse);
    });

    test('should_mute_music_and_persist_when_toggled', () async {
      // Arrange
      final audio = FakeAudioService(musicMuted: false);
      final container = _containerWith(audio);

      // Act
      await container
          .read(audioSettingsControllerProvider.notifier)
          .toggleMusic();

      // Assert — el estado reactivo y la fachada quedan sincronizados.
      expect(container.read(audioSettingsControllerProvider).musicMuted, isTrue);
      expect(audio.musicMuted, isTrue);
    });

    test('should_toggle_sfx_independently_of_music', () async {
      // Arrange
      final audio = FakeAudioService(musicMuted: true, sfxMuted: false);
      final container = _containerWith(audio);

      // Act
      await container
          .read(audioSettingsControllerProvider.notifier)
          .toggleSfx();

      // Assert — SFX cambia, música intacta.
      final state = container.read(audioSettingsControllerProvider);
      expect(state.sfxMuted, isTrue);
      expect(state.musicMuted, isTrue);
    });
  });
}
