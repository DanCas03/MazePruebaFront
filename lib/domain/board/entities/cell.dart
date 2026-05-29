// lib/domain/entities/cell.dart
import '../../game_core/value_objects/position.dart';

abstract class ICell {
  Position get position;
  bool get isPassable;
  
  // Método que permite la interacción (ej. rotar la flecha).
  // Las celdas que no interactúan pueden dejarlo vacío.
  void interact(); 
}