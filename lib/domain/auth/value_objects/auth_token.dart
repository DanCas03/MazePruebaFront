import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Value Object que encapsula el JWT emitido por el back (`{ token }`).
///
/// Dart puro (sin Flutter): valida que el token no sea vacío y sabe leer el
/// claim `exp` para decidir, en el arranque, si la sesión sigue viva sin
/// necesidad de re-login. La firma NO se verifica aquí — eso es tarea del
/// servidor; localmente solo evitamos auto-loguear con un token ya caducado.
class AuthToken extends Equatable {
  final String value;

  AuthToken(this.value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('AuthToken value must not be empty');
    }
  }

  /// `true` solo si el token trae un `exp` decodificable y ya pasó.
  /// Ante cualquier duda (token opaco, sin `exp`, payload corrupto) devuelve
  /// `false`: preferimos intentar la sesión y dejar que el server responda 401
  /// antes que bloquear a un usuario con un token potencialmente válido.
  bool isExpired({DateTime? now}) {
    final exp = _expiry();
    if (exp == null) return false;
    return !(now ?? DateTime.now()).isBefore(exp);
  }

  /// Decodifica el claim `exp` (segundos epoch) del payload del JWT.
  /// Devuelve `null` si el token no es un JWT decodificable o no trae `exp`.
  DateTime? _expiry() {
    final parts = value.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload);
      if (claims is! Map || claims['exp'] is! int) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (claims['exp'] as int) * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [value];
}
