import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/providers/leaderboard_providers.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/global_leaderboard.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/leaderboard/screens/global_leaderboard_screen.dart';

void main() {
  GlobalLeaderboardEntry entry({
    String username = 'ana',
    int totalScore = 900,
    int totalStars = 12,
    int rank = 1,
  }) =>
      GlobalLeaderboardEntry(
        username: username,
        totalScore: totalScore,
        totalStars: totalStars,
        rank: rank,
      );

  /// Cinco jugadores: 3 al podio + 2 a la lista.
  List<GlobalLeaderboardEntry> topFive() => [
        entry(username: 'ana', totalScore: 900, rank: 1),
        entry(username: 'leo', totalScore: 800, rank: 2),
        entry(username: 'mia', totalScore: 700, rank: 3),
        entry(username: 'sam', totalScore: 600, rank: 4),
        entry(username: 'val', totalScore: 500, rank: 5),
      ];

  // Monta la pantalla con el provider sobreescrito para forzar cada estado de
  // AsyncValue sin tocar la red. Locale fijo en 'es' (idioma primario) para
  // aserir las cadenas localizadas, igual que el widget test del por-nivel.
  Widget harness(Override override) => ProviderScope(
        overrides: [override],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GlobalLeaderboardScreen(),
        ),
      );

  testWidgets('should_show_loading_indicator_when_provider_pending',
      (tester) async {
    // Arrange — future que nunca completa => estado de carga
    await tester.pumpWidget(harness(
      globalLeaderboardProvider
          .overrideWith((ref) => Completer<GlobalLeaderboard>().future),
    ));
    // Assert — sin settle, el provider sigue pendiente
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should_render_podium_and_list_rows_when_top_has_data',
      (tester) async {
    // Arrange
    await tester.pumpWidget(harness(
      globalLeaderboardProvider.overrideWith(
        (ref) async => GlobalLeaderboard(top: topFive(), me: null),
      ),
    ));
    await tester.pumpAndSettle();
    // Assert — el podio pinta a los 3 primeros y la lista al 4º y 5º
    // (match exacto: 'ana' aparece como substring en otros textos de la UI).
    for (final name in ['ana', 'leo', 'mia', 'sam', 'val']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byIcon(Icons.emoji_events), findsOneWidget); // corona del nº 1
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('600'), findsOneWidget);
  });

  testWidgets('should_show_empty_state_when_top_is_empty', (tester) async {
    // Arrange
    await tester.pumpWidget(harness(
      globalLeaderboardProvider.overrideWith(
        (ref) async => GlobalLeaderboard(top: const [], me: null),
      ),
    ));
    await tester.pumpAndSettle();
    // Assert
    expect(find.textContaining('Aún no hay jugadores'), findsOneWidget);
  });

  testWidgets('should_show_error_and_retry_reinvokes_provider',
      (tester) async {
    // Arrange — falla siempre; el contador prueba que Reintentar re-dispara
    // el provider (invalidate) y no es un botón muerto.
    var calls = 0;
    await tester.pumpWidget(harness(
      globalLeaderboardProvider.overrideWith((ref) {
        calls++;
        return Future<GlobalLeaderboard>.error(Exception('red caída'));
      }),
    ));
    await tester.pumpAndSettle();
    // Assert — estado de error pintado
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('No se pudo cargar el ranking global.'), findsOneWidget);
    expect(calls, 1);
    // Act — reintentar
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    // Assert — el provider se reinvocó
    expect(calls, 2);
  });

  testWidgets('should_anchor_me_bar_with_you_badge_when_outside_top',
      (tester) async {
    // Arrange — yo clasifico en el puesto 42, fuera del top de 5
    await tester.pumpWidget(harness(
      globalLeaderboardProvider.overrideWith(
        (ref) async => GlobalLeaderboard(
          top: topFive(),
          me: entry(username: 'dan', totalScore: 120, totalStars: 3, rank: 42),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Assert — barra propia anclada con rank real y badge "Tú"
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('dan'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
  });

  testWidgets('should_highlight_me_row_in_place_when_inside_top',
      (tester) async {
    // Arrange — yo soy el 4º: dentro del top, sin barra anclada duplicada
    await tester.pumpWidget(harness(
      globalLeaderboardProvider.overrideWith(
        (ref) async => GlobalLeaderboard(
          top: topFive(),
          me: entry(username: 'sam', totalScore: 600, rank: 4),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Assert — un solo '#4' (la fila del top, resaltada), con el badge "Tú"
    expect(find.text('#4'), findsOneWidget);
    expect(find.text('Tú'), findsOneWidget);
  });

  testWidgets('should_show_unranked_footer_when_me_is_null', (tester) async {
    // Arrange
    await tester.pumpWidget(harness(
      globalLeaderboardProvider.overrideWith(
        (ref) async => GlobalLeaderboard(top: topFive(), me: null),
      ),
    ));
    await tester.pumpAndSettle();
    // Assert
    expect(find.textContaining('Aún no clasificas'), findsOneWidget);
  });
}
