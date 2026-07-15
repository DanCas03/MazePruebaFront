import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/auth/entities/user_profile.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/email.dart';
import 'package:flutter_arrow_maze/domain/auth/value_objects/username.dart';

void main() {
  group('UserProfile', () {
    test('exposes the identity, username and email it is built with', () {
      // Arrange
      final profile = UserProfile(
        id: 'u-1',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      );
      // Act & Assert
      expect(profile.id, 'u-1');
      expect(profile.username.value, 'player_01');
      expect(profile.email.value, 'player@arrowmaze.com');
    });

    test('two profiles with the same fields are equal (value equality)', () {
      // Arrange
      final a = UserProfile(
        id: 'u-1',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      );
      final b = UserProfile(
        id: 'u-1',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      );
      // Act & Assert
      expect(a, equals(b));
    });

    test('profiles differing in id are not equal', () {
      // Arrange
      final a = UserProfile(
        id: 'u-1',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      );
      final b = UserProfile(
        id: 'u-2',
        username: Username('player_01'),
        email: Email('player@arrowmaze.com'),
      );
      // Act & Assert
      expect(a, isNot(equals(b)));
    });
  });
}
