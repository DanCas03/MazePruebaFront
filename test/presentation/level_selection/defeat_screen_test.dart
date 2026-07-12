import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/defeat_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';

import '../../support/level_selection_fakes.dart';

/// MaterialApp localizada (front#4): locale 'en' fijo para que las aserciones
/// en inglés del ARB sean deterministas. Reemplaza a `MaterialApp` directo en
/// todos los hosts de este archivo. Va dentro de un `ProviderScope` con el
/// Catálogo remoto y el selector stubeados (front#8/#20) porque uno de los
/// hosts navega a LevelSelectionScreen, que exige ambos providers.
Widget _localizedApp({
  required RouteFactory onGenerateRoute,
}) =>
    ProviderScope(
      overrides: levelSelectionOverrides(catalogIds: [LevelId('level-01')]),
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: onGenerateRoute,
      ),
    );

/// Monta DefeatScreen detras de una ruta que inyecta los `arguments` (levelId,
/// movimientos y choques), tal como hace el flujo real al perder una partida.
Widget _appWithArgs(DefeatArgs? args) {
  return _localizedApp(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      settings: RouteSettings(arguments: args),
      builder: (_) => const DefeatScreen(),
    ),
  );
}

void main() {
  group('DefeatScreen', () {
    testWidgets('shows the moves and strikes passed as route arguments',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        _appWithArgs((levelId: LevelId('2'), moves: 3, strikes: 5)),
      );

      // Act
      // (render only)

      // Assert
      expect(find.text('Out of Moves!'), findsOneWidget);
      expect(find.text('3 moves · 5 strikes'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets('falls back to zeros and disables Retry when no arguments',
        (tester) async {
      // Arrange
      await tester.pumpWidget(_appWithArgs(null));

      // Act
      // (render only)

      // Assert
      expect(find.text('0 moves · 0 strikes'), findsOneWidget);
      final retry = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Retry'),
      );
      expect(retry.onPressed, isNull);
    });

    testWidgets('Retry reloads the level via the game route with its LevelId',
        (tester) async {
      // Arrange — capture the arguments the game route is pushed with.
      Object? gameArgs;
      await tester.pumpWidget(
        _localizedApp(
          onGenerateRoute: (settings) => switch (settings.name) {
            AppRouter.game => MaterialPageRoute<void>(
                builder: (_) {
                  gameArgs = settings.arguments;
                  // Placeholder: solo verificamos el LevelId reenviado, sin
                  // montar el GameScreen real (requiere ProviderScope).
                  return const Scaffold();
                },
              ),
            _ => MaterialPageRoute<void>(
                settings: RouteSettings(
                  arguments: (levelId: LevelId('7'), moves: 2, strikes: 5),
                ),
                builder: (_) => const DefeatScreen(),
              ),
          },
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();

      // Assert — the same LevelId is forwarded so the level reloads.
      expect(gameArgs, LevelId('7'));
    });

    testWidgets('Back to Levels returns to LevelSelectionScreen',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        _localizedApp(
          onGenerateRoute: (settings) => switch (settings.name) {
            AppRouter.levelSelection => MaterialPageRoute<void>(
                builder: (_) => const LevelSelectionScreen(),
              ),
            _ => MaterialPageRoute<void>(
                settings: RouteSettings(
                  arguments: (levelId: LevelId('1'), moves: 0, strikes: 5),
                ),
                builder: (_) => const DefeatScreen(),
              ),
          },
        ),
      );

      // Act
      await tester.tap(find.widgetWithText(TextButton, 'Back to Levels'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });
  });
}
