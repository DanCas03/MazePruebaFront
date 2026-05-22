// lib/domain/entities/cell.dart
import 'position.dart';

abstract class ICell {
  Position get position;
  bool get isPassable;
  
  // Método que permite la interacción (ej. rotar la flecha).
  // Las celdas que no interactúan pueden dejarlo vacío.
  void interact(); 
}