import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/use_cases/toggle_music_use_case.dart';

import '../../support/settings_fakes.dart';

void main() {
  group('ToggleMusicUseCase', () {
    test('should_mute_music_when_currently_unmuted', () async {
      // Arrange
      final audio = FakeAudioService(musicMuted: false);

      // Act
      final result = await ToggleMusicUseCase(audio).execute();

      // Assert
      expect(result, isTrue);
      expect(audio.musicMuted, isTrue);
    });

    test('should_unmute_music_when_currently_muted', () async {
      // Arrange
      final audio = FakeAudioService(musicMuted: true);

      // Act
      final result = await ToggleMusicUseCase(audio).execute();

      // Assert
      expect(result, isFalse);
      expect(audio.musicMuted, isFalse);
    });

    test('should_not_touch_sfx_when_toggling_music', () async {
      // Arrange
      final audio = FakeAudioService(sfxMuted: true);

      // Act
      await ToggleMusicUseCase(audio).execute();

      // Assert — el muteo de SFX es independiente y no cambia.
      expect(audio.sfxMuted, isTrue);
    });
  });
}
