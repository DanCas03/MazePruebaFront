import 'package:equatable/equatable.dart';
import '../../core/exceptions/invalid_arrow_exception.dart';

class ArrowLength extends Equatable {
  final int value;
  ArrowLength(this.value) {
    if (value < 1) throw InvalidArrowException('ArrowLength must be >= 1, got $value');
  }

  @override
  List<Object?> get props => [value];
}
