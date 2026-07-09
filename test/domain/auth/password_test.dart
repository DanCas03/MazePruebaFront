// test/domain/auth/password_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/password.dart';

void main() {
  test('accepts a password of at least 8 characters', () {
    // Arrange / Act
    final pw = Password('12345678');
    // Assert
    expect(pw.value, '12345678');
  });

  test('throws ArgumentError when shorter than 8 characters', () {
    // Arrange / Act / Assert
    expect(() => Password('1234567'), throwsArgumentError);
  });

  test('throws ArgumentError on empty', () {
    expect(() => Password(''), throwsArgumentError);
  });

  test('two passwords with the same value are equal (Equatable)', () {
    expect(Password('abcd1234'), Password('abcd1234'));
  });
}
