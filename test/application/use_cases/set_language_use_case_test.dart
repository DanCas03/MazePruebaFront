import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/use_cases/set_language_use_case.dart';

import '../../support/settings_fakes.dart';

void main() {
  group('SetLanguageUseCase', () {
    test('should_persist_language_code_when_executed', () async {
      // Arrange
      final store = FakeLocaleStore();

      // Act
      await SetLanguageUseCase(store).execute('en');

      // Assert
      expect(store.languageCode, 'en');
      expect(store.writeCount, 1);
    });

    test('should_clear_preference_when_code_is_null', () async {
      // Arrange
      final store = FakeLocaleStore('en');

      // Act
      await SetLanguageUseCase(store).execute(null);

      // Assert — null borra la preferencia (vuelve al locale del SO).
      expect(store.languageCode, isNull);
    });
  });
}
