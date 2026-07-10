import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/l10n/app_localizations.dart';

/// Verifica el delegate generado por gen-l10n (front#4): que cada locale
/// soportado resuelva sus cadenas del ARB correspondiente, incluidas las
/// plantillas con placeholders (ICU), y que la app declare ambos locales.
void main() {
  group('AppLocalizations', () {
    Future<AppLocalizations> load(WidgetTester tester, Locale locale) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return l10n;
    }

    testWidgets('should_resolve_spanish_strings_when_locale_is_es',
        (tester) async {
      // Arrange / Act
      final l10n = await load(tester, const Locale('es'));

      // Assert
      expect(l10n.homePlay, 'JUGAR');
      expect(l10n.loginTitle, 'Iniciar sesión');
      expect(l10n.gameMoves(3), 'Movimientos: 3');
      expect(l10n.defeatSummary(2, 5), '2 movimientos · 5 choques');
    });

    testWidgets('should_resolve_english_strings_when_locale_is_en',
        (tester) async {
      // Arrange / Act
      final l10n = await load(tester, const Locale('en'));

      // Assert
      expect(l10n.homePlay, 'PLAY');
      expect(l10n.loginTitle, 'Sign in');
      expect(l10n.gameMoves(3), 'Moves: 3');
      expect(l10n.defeatSummary(2, 5), '2 moves · 5 strikes');
    });

    test('should_support_both_es_and_en_locales', () {
      // Assert
      expect(AppLocalizations.supportedLocales, contains(const Locale('es')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    });
  });
}
