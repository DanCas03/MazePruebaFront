import 'cell.dart';
import '../../game_core/value_objects/position.dart';

class EmptyCell implements ICell {
  @override
  final Position position;

  EmptyCell({required this.position});

  @override
  bool get isPassable => true;

  @override
  void interact() {
    // Una celda vacía no hace nada al ser tocada
  }
}