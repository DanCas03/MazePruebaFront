import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/domain/game_core/services/i_ticker.dart';

void main() {
  test('NullTicker.elapsed no emite nada', () async {
    // Arrange / Act
    final isEmpty = await const NullTicker().elapsed().isEmpty;
    // Assert
    expect(isEmpty, isTrue);
  });
}
