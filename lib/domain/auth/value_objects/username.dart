import 'package:equatable/equatable.dart';

/// Value Object del nombre de usuario en el registro. Encapsula la misma
/// política que el back (RegisterDto.username: 3-20 chars, letras/dígitos/
/// guion bajo) como regla de dominio reutilizable (DRY, SRP).
class Username extends Equatable {
  static const int minLength = 3;
  static const int maxLength = 20;
  static final RegExp _pattern = RegExp(r'^[A-Za-z0-9_]+$');

  final String value;

  Username(this.value) {
    if (value.length < minLength ||
        value.length > maxLength ||
        !_pattern.hasMatch(value)) {
      throw ArgumentError('Invalid username: $value');
    }
  }

  @override
  List<Object?> get props => [value];
}
