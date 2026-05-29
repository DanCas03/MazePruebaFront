import 'cell.dart';
import '../../game_core/value_objects/position.dart';

class ExitCell implements ICell {
  @override
  final Position position;

  ExitCell({required this.position});

  @override
  bool get isPassable => true;

  @override
  void interact() {
    // Lógica opcional al tocar la salida, si aplica
  }
}