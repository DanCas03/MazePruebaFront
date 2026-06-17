import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_length.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_arrow_exception.dart';

void main() {
  group('ArrowLength', () {
    test('creates with value >= 1', () {
      expect(ArrowLength(2).value, 2);
    });

    test('throws InvalidArrowException when value < 1', () {
      expect(() => ArrowLength(0), throwsA(isA<InvalidArrowException>()));
    });
  });
}
