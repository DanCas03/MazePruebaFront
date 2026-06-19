import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';

void main() {
  test('number parsea el valor numérico', () {
    // Arrange / Act / Assert
    expect(LevelId('3').number, 3);
    expect(LevelId('12').number, 12);
  });

  test('number usa fallback 1 si no es numérico', () {
    // Arrange / Act / Assert
    expect(LevelId('abc').number, 1);
  });
}
