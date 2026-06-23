import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';

void main() {
  group('MoveCount', () {
    test('starts at zero', () {
      expect(const MoveCount(0).value, 0);
    });

    test('increment returns new instance with value + 1', () {
      final original = const MoveCount(3);
      final incremented = original.increment();
      expect(incremented.value, 4);
      expect(original.value, 3); // immutable
    });
  });
}
