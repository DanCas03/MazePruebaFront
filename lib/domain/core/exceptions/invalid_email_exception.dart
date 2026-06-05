// lib/domain/core/exceptions/invalid_email_exception.dart

import 'domain_exception.dart';

/// Se lanza cuando se intenta construir un `Email` con un formato inválido.
class InvalidEmailException extends DomainException {
  const InvalidEmailException(String raw)
      : super('Formato de email inválido: "$raw"');
}
