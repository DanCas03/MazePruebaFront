/// Eventos sonoros que la fachada de audio sabe reproducir.
///
/// Mapear un evento de juego (choque, salida, victoria, derrota) a este enum es
/// responsabilidad del observador en la capa de presentacion. El dominio y la
/// aplicacion NUNCA conocen el sonido: la regla de dependencia CLEAN se
/// preserva porque el audio es un efecto de presentacion, no una invariante.
enum GameSound { exit, collision, victory, defeat }

/// Facade (GoF) del subsistema de audio.
///
/// La presentacion (y cualquier consumidor) dependen SOLO de este puerto (DIP);
/// nunca del package concreto ni de la gestion de canales/formatos/players. La
/// fachada expone tres muteos INDEPENDIENTES (master / musica / SFX) cuyo estado
/// PERSISTE entre sesiones (minimo de app 5.1.9).
abstract interface class IAudioService {
  /// Carga el estado de mute persistido y prepara el subsistema. Idempotente:
  /// invocar mas de una vez no tiene efectos adicionales.
  Future<void> init();

  /// Reproduce un efecto puntual. Silencioso si `master` o `sfx` estan muteados.
  Future<void> play(GameSound sound);

  /// Arranca la musica de fondo en bucle. Silenciosa si `master` o `music`
  /// estan muteados; si se desmutea despues, la musica se reanuda.
  Future<void> startMusic();

  /// Detiene la musica de fondo.
  Future<void> stopMusic();

  /// Muteo global (afecta a musica y SFX).
  bool get masterMuted;

  /// Muteo solo de la musica de fondo (independiente de los SFX).
  bool get musicMuted;

  /// Muteo solo de los efectos (independiente de la musica).
  bool get sfxMuted;

  /// Activa/desactiva el muteo global; al mutear detiene todo. Persiste.
  Future<void> setMasterMuted(bool muted);

  /// Activa/desactiva el muteo de la musica (independiente). Persiste.
  Future<void> setMusicMuted(bool muted);

  /// Activa/desactiva el muteo de los SFX (independiente). Persiste.
  Future<void> setSfxMuted(bool muted);

  /// Libera los recursos del subsistema (players nativos).
  Future<void> dispose();
}
