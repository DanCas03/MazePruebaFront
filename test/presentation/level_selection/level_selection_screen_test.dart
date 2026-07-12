import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/providers/level_catalog_provider.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/domain/board/entities/level.dart';
import 'package:flutter_arrow_maze/domain/board/failures/level_failure.dart';
import 'package:flutter_arrow_maze/domain/board/repositories/i_level_repository.dart';
import 'package:flutter_arrow_maze/domain/board/value_objects/level_id.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
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

/// Doble de test del Notifier del Catálogo: fuerza cada `AsyncValue` (loading /
/// data / error) según lo que devuelva o lance [_builder], sin red ni prefetch.
/// Aísla la pantalla del comportamiento del Notifier real (ya cubierto aparte).
class _FakeCatalog extends LevelCatalogNotifier {
  final FutureOr<List<LevelId>> Function() _builder;
  _FakeCatalog(this._builder) : super(_UnusedRepo(), _NoopLogger());

  @override
  Future<List<LevelId>> build() async => _builder();
}

/// Monta la pantalla real dentro de un `ProviderScope` que sobreescribe el
/// Catálogo con [catalogFactory], y un `MaterialApp` en inglés cuyo
/// `onGenerateRoute` registra en [pushed] cada navegación por nombre para poder
/// aseverar el destino y sus `arguments` (el `LevelId` real).
Widget _appUnderTest(
  LevelCatalogNotifier Function() catalogFactory, {
  List<RouteSettings>? pushed,
}) {
  return ProviderScope(
    overrides: [
      levelCatalogProvider.overrideWith(catalogFactory),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      onGenerateRoute: (settings) {
        pushed?.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: SizedBox.shrink()),
        );
      },
      home: const LevelSelectionScreen(),
    ),
  );
}

void main() {
  group('LevelSelectionScreen', () {
    final ids = [LevelId('level-01'), LevelId('level-02'), LevelId('level-03')];

    testWidgets('should_show_spinner_when_catalog_is_loading', (tester) async {
      // Arrange: un build() que nunca resuelve mantiene el estado en loading.
      final pending = Completer<List<LevelId>>();

      // Act: solo `pumpWidget` (nunca `pumpAndSettle`: el spinner anima siempre).
      await tester.pumpWidget(
        _appUnderTest(() => _FakeCatalog(() => pending.future)),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should_show_error_and_retry_when_catalog_fails',
        (tester) async {
      // Arrange
      LevelCatalogNotifier factory() =>
          _FakeCatalog(() => throw const LevelUnavailable());

      // Act
      await tester.pumpWidget(_appUnderTest(factory));
      await tester.pumpAndSettle();

      // Assert: mensaje localizado + botón de reintentar con su etiqueta.
      expect(find.text("Couldn't load levels"), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets('should_reload_catalog_when_retry_is_tapped', (tester) async {
      // Arrange: arranca en error; al reintentar (refresh → build) hay datos.
      var shouldFail = true;
      LevelCatalogNotifier factory() => _FakeCatalog(() {
            if (shouldFail) throw const LevelUnavailable();
            return ids;
          });
      await tester.pumpWidget(_appUnderTest(factory));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing); // precondición: estado error
      shouldFail = false; // el back ya responde

      // Act: tocar reintentar dispara refresh() → re-ejecuta build().
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // Assert: el refresh recargó el Catálogo y la cuadrícula aparece.
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('should_render_three_cells_when_catalog_has_three_ids',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(_appUnderTest(() => _FakeCatalog(() => ids)));
      await tester.pumpAndSettle();

      // Assert: cada celda muestra su POSICIÓN (i+1), no el id del back.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('should_navigate_to_game_with_real_id_when_first_cell_is_tapped',
        (tester) async {
      // Arrange
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        _appUnderTest(() => _FakeCatalog(() => ids), pushed: pushed),
      );
      await tester.pumpAndSettle();

      // Act: la primera celda muestra '1' pero debe navegar con el id REAL.
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      // Assert: ruta del juego con LevelId('level-01') como argumento.
      expect(pushed, hasLength(1));
      expect(pushed.single.name, AppRouter.game);
      expect(pushed.single.arguments, LevelId('level-01'));
    });
  });
}
