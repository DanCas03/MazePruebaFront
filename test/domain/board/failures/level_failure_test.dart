import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';

void main() {
  group('LevelFailure', () {
    test('should_be_equal_when_LevelNotFound_ids_are_equal', () {
      // Arrange
      final failureA = LevelNotFound(LevelId('level-07'));
      final failureB = LevelNotFound(LevelId('level-07'));
      // Act
      final result = failureA == failureB;
      // Assert
      expect(result, isTrue);
    });

    test('should_not_be_equal_when_LevelNotFound_ids_differ', () {
      // Arrange
      final failureA = LevelNotFound(LevelId('level-07'));
      final failureB = LevelNotFound(LevelId('level-08'));
      // Act
      final result = failureA == failureB;
      // Assert
      expect(result, isFalse);
    });

    test('should_be_equal_when_both_are_LevelUnavailable', () {
      // Arrange
      const failureA = LevelUnavailable();
      const failureB = LevelUnavailable();
      // Act
      final result = failureA == failureB;
      // Assert
      expect(result, isTrue);
    });

    test('should_be_equal_when_LevelCorrupted_reasons_match', () {
      // Arrange
      const failureA = LevelCorrupted('bad cells');
      const failureB = LevelCorrupted('bad cells');
      // Act
      final result = failureA == failureB;
      // Assert
      expect(result, isTrue);
    });

    test('should_not_be_equal_when_LevelCorrupted_reasons_differ', () {
      // Arrange
      const failureA = LevelCorrupted('bad cells');
      const failureB = LevelCorrupted('bad direction');
      // Act
      final result = failureA == failureB;
      // Assert
      expect(result, isFalse);
    });

    test('should_include_level_id_when_LevelNotFound_message_is_read', () {
      // Arrange
      final failure = LevelNotFound(LevelId('level-07'));
      // Act
      final message = failure.message;
      // Assert
      expect(message, contains('level-07'));
    });

    test('should_have_fixed_message_when_LevelUnavailable_message_is_read',
        () {
      // Arrange
      const failure = LevelUnavailable();
      // Act
      final message = failure.message;
      // Assert
      expect(message, contains('unavailable'));
    });

    test('should_include_reason_when_LevelCorrupted_message_is_read', () {
      // Arrange
      const failure = LevelCorrupted('bad cells');
      // Act
      final message = failure.message;
      // Assert
      expect(message, contains('bad cells'));
    });

    test(
        'should_match_each_subtype_exhaustively_when_switching_over_LevelFailure',
        () {
      // Arrange
      String describe(LevelFailure f) => switch (f) {
            LevelNotFound() => 'nf',
            LevelUnavailable() => 'un',
            LevelCorrupted() => 'co',
          };
      final notFound = LevelNotFound(LevelId('level-07'));
      const unavailable = LevelUnavailable();
      const corrupted = LevelCorrupted('bad cells');
      // Act
      final notFoundResult = describe(notFound);
      final unavailableResult = describe(unavailable);
      final corruptedResult = describe(corrupted);
      // Assert
      expect(notFoundResult, 'nf');
      expect(unavailableResult, 'un');
      expect(corruptedResult, 'co');
    });
  });
}
