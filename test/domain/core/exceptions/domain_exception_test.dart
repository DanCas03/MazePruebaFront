import 'package:flutter_arrow_maze/domain/core/exceptions/arrow_not_found_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/domain_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_arrow_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_level_id_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_move_count_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_position_exception.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/level_not_found_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DomainException hierarchy', () {
    test('every domain exception is an Exception', () {
      // Arrange
      final exceptions = <DomainException>[
        const InvalidPositionException('msg'),
        const InvalidArrowException('msg'),
        const InvalidLevelIdException('msg'),
        const InvalidMoveCountException('msg'),
        const ArrowNotFoundException('msg'),
        const LevelNotFoundException('msg'),
      ];

      // Act & Assert
      for (final exception in exceptions) {
        expect(exception, isA<Exception>());
        expect(exception, isA<DomainException>());
      }
    });

    test('exposes the message passed to the constructor', () {
      // Arrange
      const expectedMessage = 'something went wrong';

      // Act
      const exception = InvalidPositionException(expectedMessage);

      // Assert
      expect(exception.message, expectedMessage);
    });

    test('toString includes runtimeType and message', () {
      // Arrange
      const exception = ArrowNotFoundException('arrow 42 is missing');

      // Act
      final result = exception.toString();

      // Assert
      expect(result, 'ArrowNotFoundException: arrow 42 is missing');
    });
  });

  group('InvalidPositionException', () {
    test('is a DomainException carrying its message', () {
      // Arrange & Act
      const exception = InvalidPositionException('out of bounds');

      // Assert
      expect(exception, isA<DomainException>());
      expect(exception.message, 'out of bounds');
      expect(exception.toString(), 'InvalidPositionException: out of bounds');
    });
  });

  group('InvalidArrowException', () {
    test('is a DomainException carrying its message', () {
      // Arrange & Act
      const exception = InvalidArrowException('bad arrow');

      // Assert
      expect(exception, isA<DomainException>());
      expect(exception.message, 'bad arrow');
      expect(exception.toString(), 'InvalidArrowException: bad arrow');
    });
  });

  group('InvalidLevelIdException', () {
    test('is a DomainException carrying its message', () {
      // Arrange & Act
      const exception = InvalidLevelIdException('bad level id');

      // Assert
      expect(exception, isA<DomainException>());
      expect(exception.message, 'bad level id');
      expect(exception.toString(), 'InvalidLevelIdException: bad level id');
    });
  });

  group('InvalidMoveCountException', () {
    test('is a DomainException carrying its message', () {
      // Arrange & Act
      const exception = InvalidMoveCountException('negative moves');

      // Assert
      expect(exception, isA<DomainException>());
      expect(exception.message, 'negative moves');
      expect(exception.toString(), 'InvalidMoveCountException: negative moves');
    });
  });

  group('ArrowNotFoundException', () {
    test('is a DomainException carrying its message', () {
      // Arrange & Act
      const exception = ArrowNotFoundException('arrow missing');

      // Assert
      expect(exception, isA<DomainException>());
      expect(exception.message, 'arrow missing');
      expect(exception.toString(), 'ArrowNotFoundException: arrow missing');
    });
  });

  group('LevelNotFoundException', () {
    test('is a DomainException carrying its message', () {
      // Arrange & Act
      const exception = LevelNotFoundException('level missing');

      // Assert
      expect(exception, isA<DomainException>());
      expect(exception.message, 'level missing');
      expect(exception.toString(), 'LevelNotFoundException: level missing');
    });
  });
}
