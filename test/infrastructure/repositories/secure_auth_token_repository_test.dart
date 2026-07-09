import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_arrow_maze/domain/auth/value_objects/auth_token.dart';
import 'package:flutter_arrow_maze/infrastructure/data_sources/local/secure_token_data_source.dart';
import 'package:flutter_arrow_maze/infrastructure/repositories/secure_auth_token_repository.dart';

import 'secure_auth_token_repository_test.mocks.dart';

@GenerateMocks([SecureTokenDataSource])
void main() {
  late MockSecureTokenDataSource mockDataSource;
  late SecureAuthTokenRepository repository;

  setUp(() {
    mockDataSource = MockSecureTokenDataSource();
    repository = SecureAuthTokenRepository(mockDataSource);
  });

  group('save', () {
    test('writes the unwrapped JWT string to the data source', () async {
      // Arrange
      final token = AuthToken('header.payload.sig');
      when(mockDataSource.write('header.payload.sig'))
          .thenAnswer((_) async {});
      // Act
      await repository.save(token);
      // Assert
      verify(mockDataSource.write('header.payload.sig')).called(1);
    });
  });

  group('read', () {
    test('returns an AuthToken wrapping the stored value when present',
        () async {
      // Arrange
      when(mockDataSource.read())
          .thenAnswer((_) async => 'header.payload.sig');
      // Act
      final result = await repository.read();
      // Assert
      expect(result, AuthToken('header.payload.sig'));
    });

    test('returns null when the data source has no token', () async {
      // Arrange
      when(mockDataSource.read()).thenAnswer((_) async => null);
      // Act
      final result = await repository.read();
      // Assert
      expect(result, isNull);
    });

    test('returns null when the stored value is an empty string', () async {
      // Arrange — un valor vacío no es un token válido; no debe romper AuthToken
      when(mockDataSource.read()).thenAnswer((_) async => '');
      // Act
      final result = await repository.read();
      // Assert
      expect(result, isNull);
    });
  });

  group('clear', () {
    test('deletes the token from the data source', () async {
      // Arrange
      when(mockDataSource.delete()).thenAnswer((_) async {});
      // Act
      await repository.clear();
      // Assert
      verify(mockDataSource.delete()).called(1);
    });
  });
}
