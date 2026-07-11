import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/in_memory_session_token_store.dart';

void main() {
  test('current es null por defecto (sin sesión)', () {
    // Arrange / Act
    final store = InMemorySessionTokenStore();
    // Assert
    expect(store.current, isNull);
  });

  test('current devuelve el token tras fijarlo', () {
    // Arrange
    final store = InMemorySessionTokenStore();
    final token = AuthToken('jwt-1');
    // Act
    store.current = token;
    // Assert
    expect(store.current, token);
  });

  test('current vuelve a null tras limpiarlo', () {
    // Arrange
    final store = InMemorySessionTokenStore()..current = AuthToken('jwt-1');
    // Act
    store.current = null;
    // Assert
    expect(store.current, isNull);
  });
}
