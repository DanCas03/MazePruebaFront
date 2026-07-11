import '../../application/audio/i_audio_service.dart';
import 'i_audio_backend.dart';
import 'i_audio_settings_store.dart';

/// Fachada + Singleton (GoF) del subsistema de audio.
///
/// **Facade:** traduce cada [GameSound] a su ruta de asset y delega en
/// [IAudioBackend], ocultando players, formatos y modos de reproduccion. Aplica
/// las reglas de silencio de los muteos independientes.
///
/// **Singleton:** una unica instancia por vida de la app. La primera
/// construccion fija las dependencias (inyectadas desde el composition root);
/// las siguientes llamadas a `AudioService(...)` ignoran sus argumentos y
/// devuelven la misma instancia. En la app se inyecta ademas via un `Provider`
/// Riverpod, de modo que la unicidad esta garantizada por partida doble. El
/// gancho `resetForTest` permite aislar cada test.
///
/// **Reglas de silencio (muteos independientes):** un SFX suena solo si NO hay
/// `master` ni `sfx` muteados; la musica suena solo si NO hay `master` ni
/// `music` muteados. Los flags se persisten via [IAudioSettingsStore].
class AudioService implements IAudioService {
  AudioService._(this._backend, this._store);

  static AudioService? _instance;

  /// Devuelve el Singleton, creandolo con [backend] y [store] la primera vez.
  factory AudioService(IAudioBackend backend, IAudioSettingsStore store) =>
      _instance ??= AudioService._(backend, store);

  /// Descarta la instancia Singleton. **Uso exclusivo de tests** (para que cada
  /// caso arranque con dependencias frescas).
  static void resetForTest() => _instance = null;

  final IAudioBackend _backend;
  final IAudioSettingsStore _store;

  bool _master = false;
  bool _music = false;
  bool _sfx = false;

  // Intencion del usuario de tener musica sonando: si la musica se muteo y
  // luego se desmutea, se reanuda solo si esta bandera sigue activa.
  bool _musicRequested = false;

  static const Map<GameSound, String> _sfxAssets = {
    GameSound.exit: 'audio/sfx_exit.wav',
    GameSound.collision: 'audio/sfx_collision.wav',
    GameSound.victory: 'audio/sfx_victory.wav',
    GameSound.defeat: 'audio/sfx_defeat.wav',
  };
  static const String _musicAsset = 'audio/music_loop.wav';

  bool get _sfxAudible => !_master && !_sfx;
  bool get _musicAudible => !_master && !_music;

  @override
  Future<void> init() async {
    _master = _store.masterMuted;
    _music = _store.musicMuted;
    _sfx = _store.sfxMuted;
  }

  @override
  bool get masterMuted => _master;

  @override
  bool get musicMuted => _music;

  @override
  bool get sfxMuted => _sfx;

  @override
  Future<void> play(GameSound sound) async {
    if (!_sfxAudible) return;
    await _backend.playSfx(_sfxAssets[sound]!);
  }

  @override
  Future<void> startMusic() async {
    _musicRequested = true;
    if (!_musicAudible) return;
    await _backend.loopMusic(_musicAsset);
  }

  @override
  Future<void> stopMusic() async {
    _musicRequested = false;
    await _backend.stopMusic();
  }

  @override
  Future<void> setMasterMuted(bool muted) async {
    _master = muted;
    await _store.setMasterMuted(muted);
    await _reconcileMusic();
  }

  @override
  Future<void> setMusicMuted(bool muted) async {
    _music = muted;
    await _store.setMusicMuted(muted);
    await _reconcileMusic();
  }

  @override
  Future<void> setSfxMuted(bool muted) async {
    _sfx = muted;
    await _store.setSfxMuted(muted);
  }

  // Ajusta la musica a los flags actuales: la reanuda si el usuario la pidio y
  // volvio a ser audible; la detiene en caso contrario.
  Future<void> _reconcileMusic() async {
    if (_musicRequested && _musicAudible) {
      await _backend.loopMusic(_musicAsset);
    } else {
      await _backend.stopMusic();
    }
  }

  @override
  Future<void> dispose() => _backend.dispose();
}
