import 'package:equatable/equatable.dart';

/// Value Object de la contraseña en el registro. Encapsula la política mínima
/// del back (≥8) como regla de dominio reutilizable, para no esparcir el número
/// mágico "8" por formularios y use cases (DRY, SRP).
class Password extends Equatable {
  static const int minLength = 8;
  final String value;

  Password(this.value) {
    if (value.length < minLength) {
      throw ArgumentError('Password must be at least $minLength characters');
    }
  }

  @override
  List<Object?> get props => [value];
}
