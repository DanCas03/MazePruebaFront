import 'package:equatable/equatable.dart';
import '../../core/exceptions/invalid_position_exception.dart';

class Position extends Equatable {
  final int row;
  final int col;

  Position({required this.row, required this.col}) {
    if (row < 0 || col < 0) {
      throw InvalidPositionException('row=$row col=$col must be >= 0');
    }
  }

  @override
  List<Object?> get props => [row, col];
}
