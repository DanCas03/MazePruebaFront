import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/audio/i_audio_service.dart';
import 'package:flutter_arrow_maze/infrastructure/audio/audio_service.dart';
import 'package:flutter_arrow_maze/infrastructure/audio/i_audio_backend.dart';
import 'package:flutter_arrow_maze/infrastructure/audio/i_audio_settings_store.dart';

/// Spy del backend: registra que assets se reprodujeron y cuantas veces se
/// paro/dispuso la musica, sin tocar players nativos.
class _SpyBackend implements IAudioBackend {
  final List<String> sfx = [];
  final List<String> musicStarts = [];
  int stops = 0;
  int disposes = 0;

  @override
  Future<void> playSfx(String asset) async => sfx.add(asset);

  @override
  Future<void> loopMusic(String asset) async => musicStarts.add(asset);

  @override
  Future<void> stopMusic() async => stops++;

  @override
  Future<void> dispose() async => disposes++;
}

/// Fake in-memory del store de persistencia (write-through).
class _FakeStore implements IAudioSettingsStore {
  _FakeStore({this.master = false, this.music = false, this.sfx = false});

  bool master;
  bool music;
  bool sfx;

  @override
  bool get masterMuted => master;
  @override
  bool get musicMuted => music;
  @override
  bool get sfxMuted => sfx;

  @override
  Future<void> setMasterMuted(bool value) async => master = value;
  @override
  Future<void> setMusicMuted(bool value) async => music = value;
  @override
  Future<void> setSfxMuted(bool value) async => sfx = value;
}

void main() {
  // El Singleton retiene la primera instancia: se resetea antes de cada test
  // para arrancar con dependencias frescas.
  setUp(AudioService.resetForTest);

  group('AudioService — SFX y muteos', () {
    test('should_play_exit_sfx_when_not_muted', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore());
      await service.init();

      // Act
      await service.play(GameSound.exit);

      // Assert
      expect(backend.sfx, ['audio/sfx_exit.wav']);
    });

    test('should_not_play_sfx_when_master_muted', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore(master: true));
      await service.init();

      // Act
      await service.play(GameSound.collision);

      // Assert
      expect(backend.sfx, isEmpty);
    });

    test('should_not_play_sfx_when_sfx_muted', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore(sfx: true));
      await service.init();

      // Act
      await service.play(GameSound.victory);

      // Assert
      expect(backend.sfx, isEmpty);
    });

    test('should_keep_sfx_audible_when_only_music_muted', () async {
      // Arrange — muteo independiente: silenciar la musica no silencia los SFX.
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore(music: true));
      await service.init();

      // Act
      await service.play(GameSound.exit);

      // Assert
      expect(backend.sfx, isNotEmpty);
    });
  });

  group('AudioService — musica', () {
    test('should_loop_music_when_not_muted', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore());
      await service.init();

      // Act
      await service.startMusic();

      // Assert
      expect(backend.musicStarts, ['audio/music_loop.wav']);
    });

    test('should_not_loop_music_when_music_muted', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore(music: true));
      await service.init();

      // Act
      await service.startMusic();

      // Assert
      expect(backend.musicStarts, isEmpty);
    });

    test('should_stop_music_when_music_muted_while_playing', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore());
      await service.init();
      await service.startMusic();

      // Act — mutear la musica mientras suena la detiene.
      await service.setMusicMuted(true);

      // Assert
      expect(service.musicMuted, isTrue);
      expect(backend.stops, greaterThanOrEqualTo(1));
    });

    test('should_resume_music_when_unmuted_after_being_requested', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore());
      await service.init();
      await service.startMusic();
      await service.setMusicMuted(true);
      final startsBeforeUnmute = backend.musicStarts.length;

      // Act — al desmutear se reanuda (el usuario habia pedido musica).
      await service.setMusicMuted(false);

      // Assert
      expect(backend.musicStarts.length, greaterThan(startsBeforeUnmute));
    });
  });

  group('AudioService — persistencia (5.1.9)', () {
    test('should_load_persisted_mute_flags_on_init', () async {
      // Arrange
      final store = _FakeStore(master: false, music: true, sfx: false);
      final service = AudioService(_SpyBackend(), store);

      // Act
      await service.init();

      // Assert
      expect(service.musicMuted, isTrue);
      expect(service.sfxMuted, isFalse);
      expect(service.masterMuted, isFalse);
    });

    test('should_persist_sfx_mute_when_toggled', () async {
      // Arrange
      final store = _FakeStore();
      final service = AudioService(_SpyBackend(), store);
      await service.init();

      // Act
      await service.setSfxMuted(true);

      // Assert — persistido en el store y reflejado en memoria.
      expect(store.sfxMuted, isTrue);
      expect(service.sfxMuted, isTrue);
    });
  });

  group('AudioService — Singleton y ciclo de vida', () {
    test('should_return_same_instance_when_constructed_twice', () {
      // Arrange & Act
      final first = AudioService(_SpyBackend(), _FakeStore());
      final second = AudioService(_SpyBackend(), _FakeStore());

      // Assert
      expect(identical(first, second), isTrue);
    });

    test('should_dispose_backend_when_disposed', () async {
      // Arrange
      final backend = _SpyBackend();
      final service = AudioService(backend, _FakeStore());

      // Act
      await service.dispose();

      // Assert
      expect(backend.disposes, 1);
    });
  });
}
