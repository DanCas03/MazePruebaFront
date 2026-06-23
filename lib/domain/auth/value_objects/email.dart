import 'package:equatable/equatable.dart';

final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

class Email extends Equatable {
  final String value;
  Email(this.value) {
    if (!_emailRegex.hasMatch(value)) {
      throw ArgumentError('Invalid email: $value');
    }
  }

  @override
  List<Object?> get props => [value.toLowerCase()];
}
