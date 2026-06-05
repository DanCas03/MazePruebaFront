// lib/domain/auth/value_objects/email.dart

import '../../core/exceptions/invalid_email_exception.dart';

/// Value Object que garantiza que un email es sintácticamente válido.
///
/// DDD: el invariante (formato correcto) vive dentro del propio tipo. Una vez
/// que tienes un `Email`, el resto del sistema puede confiar en que es válido
/// sin volver a validarlo (evita validaciones dispersas y primitive obsession
/// con `String`).
class Email {
  final String value;

  const Email._(this.value);

  /// Construye un [Email] validado o lanza [InvalidEmailException].
  factory Email.of(String raw) {
    final normalized = raw.trim();
    if (!_pattern.hasMatch(normalized)) {
      throw InvalidEmailException(raw);
    }
    return Email._(normalized);
  }

  static final RegExp _pattern = RegExp(r'^[\w.\-+]+@[\w\-]+\.[\w.\-]+$');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Email && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
