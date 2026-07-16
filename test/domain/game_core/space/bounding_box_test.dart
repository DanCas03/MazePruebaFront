import 'package:flutter_arrow_maze/domain/game_core/space/bounding_box.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoundingBox', () {
    test('should_expose_origin_dimensions_and_derived_max_edges', () {
      // Arrange & Act
      const box = BoundingBox(minRow: 2, minCol: 3, rows: 4, cols: 5);
      // Assert
      expect(box.minRow, 2);
      expect(box.minCol, 3);
      expect(box.rows, 4);
      expect(box.cols, 5);
      expect(box.maxRow, 5); // 2 + 4 - 1
      expect(box.maxCol, 7); // 3 + 5 - 1
    });

    test('should_contain_only_positions_within_the_box', () {
      // Arrange
      const box = BoundingBox(minRow: 2, minCol: 3, rows: 4, cols: 5);
      // Act & Assert
      expect(box.contains(Position(row: 2, col: 3)), isTrue); // esquina min
      expect(box.contains(Position(row: 5, col: 7)), isTrue); // esquina max
      expect(box.contains(Position(row: 1, col: 3)), isFalse); // fila fuera
      expect(box.contains(Position(row: 2, col: 8)), isFalse); // col fuera
    });

    test('should_report_empty_when_a_dimension_is_zero', () {
      // Arrange & Act & Assert
      expect(
        const BoundingBox(minRow: 0, minCol: 0, rows: 0, cols: 0).isEmpty,
        isTrue,
      );
      expect(
        const BoundingBox(minRow: 0, minCol: 0, rows: 3, cols: 2).isEmpty,
        isFalse,
      );
    });

    test('should_be_equal_by_value', () {
      // Arrange & Act & Assert
      expect(
        const BoundingBox(minRow: 1, minCol: 1, rows: 2, cols: 2),
        const BoundingBox(minRow: 1, minCol: 1, rows: 2, cols: 2),
      );
      expect(
        const BoundingBox(minRow: 1, minCol: 1, rows: 2, cols: 2),
        isNot(const BoundingBox(minRow: 0, minCol: 1, rows: 2, cols: 2)),
      );
    });
  });
}
