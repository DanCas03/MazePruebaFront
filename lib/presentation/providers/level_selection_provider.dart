// Re-exporta el provider del LevelSelectionController para que la capa
// presentation importe el estado de selección desde un único punto (facade) sin
// alcanzar directamente a `application/state/`.
export '../../application/state/level_selection_controller.dart'
    show levelSelectionControllerProvider;
