/// Puerto fino sobre el package de audio concreto.
///
/// Aisla `audioplayers` para que la fachada [AudioService] no dependa de su API
/// (Adapter/seam de test): en los tests se mockea este puerto en vez del
/// package. Recibe rutas de asset relativas a la carpeta `assets/`
/// (p. ej. `audio/sfx_exit.wav`).
abstract interface class IAudioBackend {
  /// Reproduce un efecto puntual (one-shot).
  Future<void> playSfx(String asset);

  /// Reproduce musica en bucle continuo.
  Future<void> loopMusic(String asset);

  /// Detiene la musica de fondo.
  Future<void> stopMusic();

  /// Libera los players nativos.
  Future<void> dispose();
}
