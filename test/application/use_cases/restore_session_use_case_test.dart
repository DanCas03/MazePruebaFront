import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/application/state/auth_state.dart';
import 'package:flutter_arrow_maze/application/use_cases/restore_session_use_case.dart';
import 'package:flutter_arrow_maze/domain/auth/repositories/i_auth_token_storage.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';

import 'restore_session_use_case_test.mocks.dart';

String _jwtWithExp(DateTime exp) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.'
      '${seg({'sub': 'u1', 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

@GenerateMocks([IAuthTokenStorage])
void main() {
  late MockIAuthTokenStorage mockStorage;
  late RestoreSessionUseCase useCase;
  final now = DateTime.utc(2026, 7, 8, 12, 0, 0);

  setUp(() {
    mockStorage = MockIAuthTokenStorage();
    useCase = RestoreSessionUseCase(mockStorage);
  });

  test('returns Unauthenticated when no token is stored', () async {
    // Arrange
    when(mockStorage.read()).thenAnswer((_) async => null);
    // Act
    final result = await useCase.execute(now: now);
    // Assert
    expect(result, isA<Unauthenticated>());
  });

  test('returns Authenticated with the token when a valid token is stored',
      () async {
    // Arrange — token que expira dentro de 7 días (aún válido)
    final token = AuthToken(_jwtWithExp(now.add(const Duration(days: 7))));
    when(mockStorage.read()).thenAnswer((_) async => token);
    // Act
    final result = await useCase.execute(now: now);
    // Assert
    expect(result, isA<Authenticated>());
    expect((result as Authenticated).token, token);
  });

  test('returns Unauthenticated and clears storage when token is expired',
      () async {
    // Arrange — token expirado hace una hora
    final token = AuthToken(_jwtWithExp(now.subtract(const Duration(hours: 1))));
    when(mockStorage.read()).thenAnswer((_) async => token);
    when(mockStorage.clear()).thenAnswer((_) async {});
    // Act
    final result = await useCase.execute(now: now);
    // Assert
    expect(result, isA<Unauthenticated>());
    verify(mockStorage.clear()).called(1);
  });

  test('does not clear storage when a valid token is restored', () async {
    // Arrange
    final token = AuthToken(_jwtWithExp(now.add(const Duration(days: 7))));
    when(mockStorage.read()).thenAnswer((_) async => token);
    // Act
    await useCase.execute(now: now);
    // Assert
    verifyNever(mockStorage.clear());
  });
}
