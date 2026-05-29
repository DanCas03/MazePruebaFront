// lib/domain/decorators/cell_decorator.dart
import '../entities/cell.dart';
import '../../game_core/value_objects/position.dart';

/// Clase base para los decoradores. 
/// Implementa ICell y recibe otra ICell (la que va a decorar).
abstract class CellDecorator implements ICell {
  final ICell wrappedCell;

  CellDecorator(this.wrappedCell);

  @override
  Position get position => wrappedCell.position;

  @override
  bool get isPassable => wrappedCell.isPassable;

  @override
  void interact() {
    wrappedCell.interact();
  }
}