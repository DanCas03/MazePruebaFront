import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/infrastructure/time/system_ticker.dart';

void main() {
  test('SystemTicker.elapsed cuenta hacia arriba empezando en 1', () async {
    // Arrange / Act — solo el primer valor para no depender de varios segundos.
    final first = await const SystemTicker().elapsed().first;
    // Assert
    expect(first, 1);
  });
}
