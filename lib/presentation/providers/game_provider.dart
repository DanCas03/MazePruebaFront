// Re-exporta el provider del GameController para que la capa presentation
// importe el estado de juego desde un unico punto (facade) sin alcanzar
// directamente a `application/state/`.
export '../../application/state/game_controller.dart' show gameControllerProvider;
