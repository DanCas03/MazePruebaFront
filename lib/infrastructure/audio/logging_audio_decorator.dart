import '../../application/audio/i_audio_service.dart';
import '../../core/aspects/i_logger_service.dart';

/// Decorator (GoF) + AOP: envuelve un [IAudioService] y registra cada operacion
/// via [ILoggerService], SIN modificar la logica de audio.
///
/// Es el segundo aspecto transversal del cliente (ademas del logging de errores
/// del `SyncProgressUseCase`), aplicado por composicion en el composition root:
/// el logging del audio no ensucia la fachada ni la presentacion. Al implementar
/// el mismo puerto, es transparente para el consumidor (DIP).
class LoggingAudioDecorator implements IAudioService {
  LoggingAudioDecorator(this._inner, this._logger);

  final IAudioService _inner;
  final ILoggerService _logger;

  static const String _ctx = 'Audio';

  @override
  Future<void> init() async {
    _logger.log('init', _ctx);
    await _inner.init();
  }

  @override
  Future<void> play(GameSound sound) async {
    _logger.log('play ${sound.name}', _ctx);
    await _inner.play(sound);
  }

  @override
  Future<void> startMusic() async {
    _logger.log('startMusic', _ctx);
    await _inner.startMusic();
  }

  @override
  Future<void> stopMusic() async {
    _logger.log('stopMusic', _ctx);
    await _inner.stopMusic();
  }

  @override
  Future<void> setMasterMuted(bool muted) async {
    _logger.log('setMasterMuted $muted', _ctx);
    await _inner.setMasterMuted(muted);
  }

  @override
  Future<void> setMusicMuted(bool muted) async {
    _logger.log('setMusicMuted $muted', _ctx);
    await _inner.setMusicMuted(muted);
  }

  @override
  Future<void> setSfxMuted(bool muted) async {
    _logger.log('setSfxMuted $muted', _ctx);
    await _inner.setSfxMuted(muted);
  }

  @override
  Future<void> dispose() async {
    _logger.log('dispose', _ctx);
    await _inner.dispose();
  }

  // Getters: delegacion pura, sin log (lectura sin efecto).
  @override
  bool get masterMuted => _inner.masterMuted;

  @override
  bool get musicMuted => _inner.musicMuted;

  @override
  bool get sfxMuted => _inner.sfxMuted;
}
