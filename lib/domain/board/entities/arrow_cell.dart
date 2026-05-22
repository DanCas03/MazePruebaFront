// lib/domain/entities/arrow_cell.dart
import 'cell.dart'; // Están en la misma carpeta
import '../../game_core/value_objects/position.dart';
import '../../game_core/value_objects/direction.dart';

class ArrowCell implements ICell {
  @override
  final Position position;
  
  // Estado mutable: la dirección a la que apunta la flecha
  Direction currentDirection;

  ArrowCell({required this.position, required this.currentDirection});

  @override
  bool get isPassable => true;

  @override
  void interact() {
    // Lógica para rotar la flecha 90 grados en sentido horario
    switch (currentDirection) {
      case Direction.up:
        currentDirection = Direction.right;
        break;
      case Direction.right:
        currentDirection = Direction.down;
        break;
      case Direction.down:
        currentDirection = Direction.left;
        break;
      case Direction.left:
        currentDirection = Direction.up;
        break;
    }
  }
}