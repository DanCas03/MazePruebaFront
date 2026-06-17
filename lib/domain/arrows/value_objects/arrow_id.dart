import 'package:equatable/equatable.dart';

class ArrowId extends Equatable {
  final String value;
  const ArrowId(this.value);

  @override
  List<Object?> get props => [value];
}
