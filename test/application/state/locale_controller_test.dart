import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/locale_controller.dart';

import '../../support/settings_fakes.dart';

/// Compone el controller con un [FakeLocaleStore] inyectado por constructor,
/// igual que hace `main` con la HiveLocaleStore real (DIP).
ProviderContainer _containerWith(FakeLocaleStore store) {
  final container = ProviderContainer(
    overrides: [
      localeControllerProvider.overrideWith(() => LocaleController(store)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('LocaleController', () {
    test('should_follow_system_when_no_preference_persisted', () {
      // Arrange
      final container = _containerWith(FakeLocaleStore());

      // Act
      final locale = container.read(localeControllerProvider);

      // Assert — null = seguir el locale del SO.
      expect(locale, isNull);
    });

    test('should_restore_persisted_locale_when_built', () {
      // Arrange
      final container = _containerWith(FakeLocaleStore('es'));

      // Act
      final locale = container.read(localeControllerProvider);

      // Assert
      expect(locale, const Locale('es'));
    });

    test('should_update_state_and_persist_when_language_set', () async {
      // Arrange
      final store = FakeLocaleStore('es');
      final container = _containerWith(store);

      // Act
      await container
          .read(localeControllerProvider.notifier)
          .setLanguage(const Locale('en'));

      // Assert
      expect(container.read(localeControllerProvider), const Locale('en'));
      expect(store.languageCode, 'en');
    });
  });
}
