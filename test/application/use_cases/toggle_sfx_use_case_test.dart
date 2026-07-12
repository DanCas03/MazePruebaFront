import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/use_cases/toggle_sfx_use_case.dart';

import '../../support/settings_fakes.dart';

void main() {
  group('ToggleSfxUseCase', () {
    test('should_mute_sfx_when_currently_unmuted', () async {
      // Arrange
      final audio = FakeAudioService(sfxMuted: false);

      // Act
      final result = await ToggleSfxUseCase(audio).execute();

      // Assert
      expect(result, isTrue);
      expect(audio.sfxMuted, isTrue);
    });

    test('should_unmute_sfx_when_currently_muted', () async {
      // Arrange
      final audio = FakeAudioService(sfxMuted: true);

      // Act
      final result = await ToggleSfxUseCase(audio).execute();

      // Assert
      expect(result, isFalse);
      expect(audio.sfxMuted, isFalse);
    });

    test('should_not_touch_music_when_toggling_sfx', () async {
      // Arrange
      final audio = FakeAudioService(musicMuted: true);

      // Act
      await ToggleSfxUseCase(audio).execute();

      // Assert — el muteo de música es independiente y no cambia.
      expect(audio.musicMuted, isTrue);
    });
  });
}
