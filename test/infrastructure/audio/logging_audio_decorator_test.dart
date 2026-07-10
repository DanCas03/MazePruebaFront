import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/audio/i_audio_service.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/infrastructure/audio/logging_audio_decorator.dart';

/// Audio interno que solo registra las llamadas recibidas (para verificar la
/// delegacion del decorator).
class _RecordingAudio implements IAudioService {
  final List<GameSound> played = [];
  int musicStarts = 0;
  int musicStops = 0;
  bool _sfxMuted = false;

  @override
  Future<void> init() async {}
  @override
  Future<void> play(GameSound sound) async => played.add(sound);
  @override
  Future<void> startMusic() async => musicStarts++;
  @override
  Future<void> stopMusic() async => musicStops++;
  @override
  bool get masterMuted => false;
  @override
  bool get musicMuted => false;
  @override
  bool get sfxMuted => _sfxMuted;
  @override
  Future<void> setMasterMuted(bool muted) async {}
  @override
  Future<void> setMusicMuted(bool muted) async {}
  @override
  Future<void> setSfxMuted(bool muted) async => _sfxMuted = muted;
  @override
  Future<void> dispose() async {}
}

/// Spy del logger AOP: captura mensaje y contexto de cada registro.
class _SpyLogger implements ILoggerService {
  final List<String> messages = [];
  final List<String> contexts = [];

  @override
  void log(String message, String context) {
    messages.add(message);
    contexts.add(context);
  }

  @override
  void error(String message, String context, [Object? error]) {}
  @override
  void warn(String message, String context) {}
}

void main() {
  group('LoggingAudioDecorator (AOP)', () {
    test('should_log_and_delegate_when_play', () async {
      // Arrange
      final inner = _RecordingAudio();
      final logger = _SpyLogger();
      final decorated = LoggingAudioDecorator(inner, logger);

      // Act
      await decorated.play(GameSound.victory);

      // Assert — registra el aspecto y delega el efecto.
      expect(inner.played, [GameSound.victory]);
      expect(logger.messages, contains('play victory'));
      expect(logger.contexts, everyElement('Audio'));
    });

    test('should_log_and_delegate_when_toggling_mute', () async {
      // Arrange
      final inner = _RecordingAudio();
      final logger = _SpyLogger();
      final decorated = LoggingAudioDecorator(inner, logger);

      // Act
      await decorated.setSfxMuted(true);

      // Assert
      expect(inner.sfxMuted, isTrue);
      expect(logger.messages, contains('setSfxMuted true'));
    });

    test('should_delegate_getter_without_logging', () {
      // Arrange
      final inner = _RecordingAudio();
      final logger = _SpyLogger();
      final decorated = LoggingAudioDecorator(inner, logger);

      // Act
      final muted = decorated.masterMuted;

      // Assert — leer un getter no genera ruido en el log.
      expect(muted, isFalse);
      expect(logger.messages, isEmpty);
    });
  });
}
