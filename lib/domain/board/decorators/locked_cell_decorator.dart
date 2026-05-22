// lib/domain/decorators/locked_cell_decorator.dart
import 'cell_decorator.dart';
import '../entities/cell.dart';

class LockedCellDecorator extends CellDecorator {
  bool isLocked;

  LockedCellDecorator(ICell wrappedCell, {this.isLocked = true}) 
      : super(wrappedCell);

  /// Podemos agregar un método para desbloquear la celda
  void unlock() {
    isLocked = false;
  }

  @override
  void interact() {
    if (isLocked) {
      // Si está bloqueada, no hacemos nada (o podríamos reproducir un sonido de error)
      return;
    }
    // Si ya está desbloqueada, permitimos que la celda original se comporte normalmente
    super.interact();
  }
}