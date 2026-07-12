import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/providers/level_catalog_provider.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/home/screens/home_screen.dart';
import 'package:flutter_arrow_maze/presentation/level_selection/level_selection_screen.dart';

/// Repo que nunca se invoca: [_FakeCatalog] sobreescribe `build()` y no toca el
/// puerto, pero `LevelCatalogNotifier` exige un [ILevelRepository] en su ctor.
class _UnusedRepo implements ILevelRepository {
  @override
  Future<Either<LevelFailure, List<LevelId>>> listLevelIds() =>
      throw UnimplementedError();

  @override
  Future<Either<LevelFailure, Level>> getLevel(LevelId id) =>
      throw UnimplementedError();
}

/// Logger no-op: [_FakeCatalog] no dispara el prefetch, así que nunca loggea.
class _NoopLogger implements ILoggerService {
  @override
  void log(String message, String context) {}

  @override
  void error(String message, String context, [Object? error]) {}

  @override
  void warn(String message, String context) {}
}

/// Doble de test del Notifier del Catálogo: al navegar a LevelSelectionScreen
/// (front#8) esta lee `levelCatalogProvider`, así que el host necesita un
/// ProviderScope con el Catálogo sobreescrito para que la pantalla pueda montar.
class _FakeCatalog extends LevelCatalogNotifier {
  _FakeCatalog() : super(_UnusedRepo(), _NoopLogger());

  @override
  Future<List<LevelId>> build() async => [LevelId('level-01')];
}

/// Construye una app minima centrada en HomeScreen, con el router real para
/// poder verificar la navegacion declarada por nombre de ruta. Locale fijado a
/// 'es' (front#4) para que las aserciones en español sean deterministas. Va
/// dentro de un `ProviderScope` que sobreescribe `levelCatalogProvider` porque
/// la navegación a LevelSelectionScreen monta un ConsumerWidget que lo lee.
Widget _appUnderTest() {
  return ProviderScope(
    overrides: [
      levelCatalogProvider.overrideWith(() => _FakeCatalog()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRouter.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders title, tagline and the Play CTA', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      // (render only)

      // Assert
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('ARROW MAZE'), findsOneWidget);
      expect(find.text('Despeja el tablero. Saca cada flecha.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'JUGAR'), findsOneWidget);
    });

    testWidgets('Play navigates to LevelSelectionScreen', (tester) async {
      // Arrange
      await tester.pumpWidget(_appUnderTest());

      // Act
      await tester.tap(find.widgetWithText(FilledButton, 'JUGAR'));
      // El logo del home anima en bucle infinito (repeat), así que
      // pumpAndSettle nunca se asentaría; bombeamos la transición de ruta
      // con pumps acotados.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Assert
      expect(find.byType(LevelSelectionScreen), findsOneWidget);
    });
  });
}
