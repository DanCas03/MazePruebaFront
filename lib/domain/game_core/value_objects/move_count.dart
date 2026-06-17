import 'package:equatable/equatable.dart';

class MoveCount extends Equatable {
  final int value;
  const MoveCount(this.value);

  MoveCount increment() => MoveCount(value + 1);

  @override
  List<Object?> get props => [value];
}
