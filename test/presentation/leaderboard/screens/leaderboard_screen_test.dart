import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/providers/leaderboard_providers.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/move_count.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/score.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/stars.dart';
import 'package:flutter_arrow_maze/domain/leaderboard/entities/leaderboard_entry.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/leaderboard/screens/leaderboard_screen.dart';

void main() {
  LeaderboardEntry entryRow({
    String userId = 'user-1',
    int score = 1200,
    int stars = 3,
  }) =>
      LeaderboardEntry(
        id: 'row-$userId',
        userId: userId,
        levelId: LevelId('3'),
        score: Score(score),
        stars: Stars.fromValue(stars),
        moves: const MoveCount(12),
        timeSeconds: 45,
        createdAt: DateTime.utc(2026, 7, 1, 10, 30),
      );

  // Monta la pantalla con la instancia del provider (levelId '3') sobreescrita
  // para forzar cada estado de AsyncValue sin tocar la red. Locale fijo en 'es'
  // (idioma primario) para aserir las cadenas localizadas (front#4).
  Widget harness(Override override) => ProviderScope(
        overrides: [override],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LeaderboardScreen(levelId: LevelId('3')),
        ),
      );

  testWidgets('should_show_loading_indicator_when_provider_pending',
      (tester) async {
    // Arrange — future que nunca completa => estado de carga
    await tester.pumpWidget(harness(
      leaderboardProvider('3')
          .overrideWith((ref) => Completer<List<LeaderboardEntry>>().future),
    ));
    // Assert — sin settle, el provider sigue pendiente
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('should_paint_entries_with_positional_rank_when_data_loads',
      (tester) async {
    // Arrange — el back devuelve ya ordenado por score desc
    await tester.pumpWidget(harness(
      leaderboardProvider('3').overrideWith(
        (ref) async => [
          entryRow(userId: 'ana', score: 900),
          entryRow(userId: 'leo', score: 500),
        ],
      ),
    ));
    await tester.pumpAndSettle();
    // Assert — filas pintadas con el rango posicional
    expect(find.text('ana'), findsOneWidget);
    expect(find.text('leo'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('900'), findsOneWidget);
  });

  testWidgets('should_show_empty_state_when_no_scores', (tester) async {
    // Arrange
    await tester.pumpWidget(harness(
      leaderboardProvider('3').overrideWith((ref) async => <LeaderboardEntry>[]),
    ));
    await tester.pumpAndSettle();
    // Assert
    expect(find.textContaining('Aún no hay puntajes'), findsOneWidget);
  });

  testWidgets('should_show_error_and_retry_when_provider_fails',
      (tester) async {
    // Arrange
    await tester.pumpWidget(harness(
      leaderboardProvider('3').overrideWith(
        (ref) => Future<List<LeaderboardEntry>>.error(Exception('red caída')),
      ),
    ));
    await tester.pumpAndSettle();
    // Assert
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
