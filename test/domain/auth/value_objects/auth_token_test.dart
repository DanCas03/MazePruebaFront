import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';

/// Construye un JWT de juguete `header.payload.signature` con el payload dado.
/// Solo el segmento central (payload) importa para decodificar `exp`.
String _jwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.signature';
}

void main() {
  group('AuthToken construction', () {
    test('exposes the raw JWT value', () {
      // Arrange
      final raw = _jwt({'sub': 'u1'});
      // Act
      final token = AuthToken(raw);
      // Assert
      expect(token.value, raw);
    });

    test('throws when the value is empty', () {
      // Arrange / Act / Assert
      expect(() => AuthToken(''), throwsArgumentError);
    });

    test('throws when the value is only whitespace', () {
      expect(() => AuthToken('   '), throwsArgumentError);
    });

    test('two tokens with the same value are equal', () {
      // Arrange
      final raw = _jwt({'sub': 'u1'});
      // Act / Assert — igualdad por valor (Equatable)
      expect(AuthToken(raw), AuthToken(raw));
    });
  });

  group('AuthToken.isExpired', () {
    final now = DateTime.utc(2026, 7, 8, 12, 0, 0);

    test('returns true when exp is in the past relative to now', () {
      // Arrange — exp = una hora antes de now
      final exp = now.subtract(const Duration(hours: 1));
      final token = AuthToken(
          _jwt({'sub': 'u1', 'exp': exp.millisecondsSinceEpoch ~/ 1000}));
      // Act
      final result = token.isExpired(now: now);
      // Assert
      expect(result, isTrue);
    });

    test('returns false when exp is in the future relative to now', () {
      // Arrange — exp = 7 días después (token largo, back#2)
      final exp = now.add(const Duration(days: 7));
      final token = AuthToken(
          _jwt({'sub': 'u1', 'exp': exp.millisecondsSinceEpoch ~/ 1000}));
      // Act / Assert
      expect(token.isExpired(now: now), isFalse);
    });

    test('returns false when the token has no exp claim', () {
      // Arrange — sin exp: no podemos afirmar expiración, no bloqueamos
      final token = AuthToken(_jwt({'sub': 'u1'}));
      // Act / Assert
      expect(token.isExpired(now: now), isFalse);
    });

    test('returns false when the token is not a decodable JWT', () {
      // Arrange — cadena opaca; el servidor validará, no bloqueamos localmente
      final token = AuthToken('not-a-jwt');
      // Act / Assert
      expect(token.isExpired(now: now), isFalse);
    });

    test('returns false when the payload is malformed base64/json', () {
      // Arrange — tres segmentos pero payload no decodificable
      final token = AuthToken('header.@@@notbase64@@@.sig');
      // Act / Assert
      expect(token.isExpired(now: now), isFalse);
    });
  });
}
