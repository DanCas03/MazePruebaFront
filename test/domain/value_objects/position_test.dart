import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/domain/core/exceptions/invalid_position_exception.dart';

void main() {
  group('Position', () {
    test('creates with valid row and col', () {
      final sut = Position(row: 2, col: 3);
      expect(sut.row, 2);
      expect(sut.col, 3);
    });

    test('throws InvalidPositionException when row is negative', () {
      expect(() => Position(row: -1, col: 0), throwsA(isA<InvalidPositionException>()));
    });

    test('throws InvalidPositionException when col is negative', () {
      expect(() => Position(row: 0, col: -1), throwsA(isA<InvalidPositionException>()));
    });

    test('Position(0,0) is valid — top-left cell', () {
      expect(() => Position(row: 0, col: 0), returnsNormally);
    });

    test('equality — same row and col are equal', () {
      expect(Position(row: 1, col: 2), equals(Position(row: 1, col: 2)));
    });

    test('equality — different row are not equal', () {
      expect(Position(row: 1, col: 2), isNot(equals(Position(row: 2, col: 2))));
    });
  });
}
