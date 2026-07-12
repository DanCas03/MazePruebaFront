import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/state/audio_settings_controller.dart';
import 'package:flutter_arrow_maze/application/state/locale_controller.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/settings/screens/settings_screen.dart';

import '../../support/settings_fakes.dart';

/// Host que reproduce el cableado real de `ArrowMazeApp`: el MaterialApp observa
/// el [localeControllerProvider], de modo que cambiar el idioma reconstruye el
/// árbol y valida el refresco EN VIVO de los textos. El store arranca en 'es'.
class _SettingsHost extends ConsumerWidget {
  const _SettingsHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    );
  }
}

/// Compone los controllers con fakes inyectados por constructor (DIP), igual que
/// `main` con las dependencias reales.
Widget _host({FakeAudioService? audio}) => ProviderScope(
      overrides: [
        audioSettingsControllerProvider.overrideWith(
          () => AudioSettingsController(audio ?? FakeAudioService()),
        ),
        localeControllerProvider.overrideWith(
          () => LocaleController(FakeLocaleStore('es')),
        ),
      ],
      child: const _SettingsHost(),
    );

void main() {
  group('SettingsScreen', () {
    testWidgets('should_show_audio_and_language_controls_when_opened',
        (tester) async {
      // Arrange
      await tester.pumpWidget(_host());

      // Act
      // (render only)

      // Assert — dos toggles de audio y las tres opciones de idioma (en español).
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(find.text('Música'), findsOneWidget);
      expect(find.text('Efectos de sonido'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('Inglés'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);
    });

    testWidgets('should_follow_system_when_system_segment_selected',
        (tester) async {
      // Arrange — arranca con preferencia explícita 'es'.
      await tester.pumpWidget(_host());
      final segmented = find.byType(SegmentedButton<String>);
      expect(
        tester.widget<SegmentedButton<String>>(segmented).selected,
        {'es'},
      );

      // Act — elige "Sistema": vuelve a seguir el locale del SO (setLanguage(null)).
      await tester.tap(find.text('Sistema'));
      await tester.pumpAndSettle();

      // Assert — el segmento seleccionado pasa a 'system' (locale = null),
      // haciendo alcanzable desde la UI el estado sin preferencia.
      expect(
        tester.widget<SegmentedButton<String>>(segmented).selected,
        {'system'},
      );
    });

    testWidgets('should_mute_music_when_music_switch_toggled', (tester) async {
      // Arrange
      final audio = FakeAudioService(musicMuted: false);
      await tester.pumpWidget(_host(audio: audio));
      final musicTile = find.widgetWithText(SwitchListTile, 'Música');

      // Act
      await tester.tap(musicTile);
      await tester.pumpAndSettle();

      // Assert — la fachada queda muteada y el switch pasa a OFF.
      expect(audio.musicMuted, isTrue);
      expect(tester.widget<SwitchListTile>(musicTile).value, isFalse);
    });

    testWidgets('should_update_texts_live_when_language_changed_to_english',
        (tester) async {
      // Arrange — arranca en español.
      await tester.pumpWidget(_host());
      expect(find.text('Música'), findsOneWidget);

      // Act — selecciona Inglés (etiqueta aún en español).
      await tester.tap(find.text('Inglés'));
      await tester.pumpAndSettle();

      // Assert — los textos se reevalúan en vivo, sin reiniciar la app.
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Sound effects'), findsOneWidget);
      expect(find.text('Música'), findsNothing);
    });
  });
}
