import 'cell.dart';
import '../../game_core/value_objects/position.dart';

class WallCell implements ICell {
  @override
  final Position position;

  WallCell({required this.position});

  @override
  bool get isPassable => false; // El jugador no puede pasar por aquí

  @override
  void interact() {
    // Una pared no interactúa
  }
}