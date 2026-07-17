import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_arrow_maze/application/commands/command_invoker.dart';
import 'package:flutter_arrow_maze/application/state/generated_game_controller.dart';
import 'package:flutter_arrow_maze/application/use_cases/generate_board_use_case.dart';
import 'package:flutter_arrow_maze/application/use_cases/remove_arrow_use_case.dart';
import 'package:flutter_arrow_maze/core/aspects/i_logger_service.dart';
import 'package:flutter_arrow_maze/core/theme/app_theme.dart';
import 'package:flutter_arrow_maze/domain/arrows/entities/arrow_board.dart';
import 'package:flutter_arrow_maze/domain/arrows/services/i_level_generator.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/arrow_id.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/difficulty.dart';
import 'package:flutter_arrow_maze/domain/arrows/value_objects/generator_config.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/direction.dart';
import 'package:flutter_arrow_maze/domain/game_core/value_objects/position.dart';
import 'package:flutter_arrow_maze/core/router/app_router.dart';
import 'package:flutter_arrow_maze/l10n/app_localizations.dart';
import 'package:flutter_arrow_maze/presentation/generated/generated_result_screen.dart';
import 'package:flutter_arrow_maze/domain/game_core/space/rect_space.dart';
import '../../support/arrow_fixtures.dart';

class _FakeGenerator implements ILevelGenerator {
  @override
  ArrowBoard generate({
    required int cols,
    required int rows,
    required int arrowCount,
    required int maxPathLen,
    int? seed,
  }) =>
      ArrowBoard(
        arrows: [
          straightArrow(
            id: const ArrowId('a0'),
            tail: Position(row: 0, col: 0),
            direction: Direction.right,
            length: 2,
          )
        ],
        space: RectSpace(cols, rows),
      );
}

class _NoopLogger implements ILoggerService {
  @override
  void log(String message, String context) {}
  @override
  void error(String message, String context, [Object? error]) {}
  @override
  void warn(String message, String context) {}
}

/// App que fuerza los [GeneratedResultArgs] en la ruta y compone el controlador
/// generado con una semilla fija (555) ya montada, para que la pantalla lea la
/// semilla del controlador vivo.
Widget _appUnderTest({required bool won}) {
  final useCase =
      GenerateBoardUseCase(_FakeGenerator(), _NoopLogger(), seedSource: () => 555);
  return ProviderScope(
    overrides: [
      generatedGameControllerProvider.overrideWith(
        () => GeneratedGameController(
            useCase, RemoveArrowUseCase(), CommandInvoker()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const GeneratedResultScreen(),
        settings: RouteSettings(arguments: (won: won, moves: 7)),
      ),
    ),
  );
}

void main() {
  group('GeneratedResultScreen', () {
    testWidgets('muestra las cuatro acciones obligatorias', (tester) async {
      final container = ProviderScope.containerOf;
      await tester.pumpWidget(_appUnderTest(won: true));
      // Monta un tablero (semilla 555) para exponer la semilla en la pantalla.
      final ctx = tester.element(find.byType(GeneratedResultScreen));
      await container(ctx)
          .read(generatedGameControllerProvider.notifier)
          .startNew(GeneratorConfig.create(
              cols: 6, rows: 10, difficulty: Difficulty.easy));
      await tester.pump();

      expect(find.text('Otro tablero'), findsOneWidget);
      expect(find.text('Repetir'), findsOneWidget);
      expect(find.text('Cambiar parámetros'), findsOneWidget);
      expect(find.text('Salir'), findsOneWidget);
    });

    testWidgets('NO muestra estrellas ni "Siguiente nivel" (sin score/stars)',
        (tester) async {
      await tester.pumpWidget(_appUnderTest(won: true));
      await tester.pump();

      expect(find.byIcon(Icons.star), findsNothing);
      expect(find.text('Siguiente nivel'), findsNothing);
      expect(find.textContaining('Puntaje'), findsNothing);
    });

    testWidgets('victoria usa el título de tablero despejado', (tester) async {
      await tester.pumpWidget(_appUnderTest(won: true));
      await tester.pump();
      expect(find.text('¡Tablero despejado!'), findsOneWidget);
    });

    testWidgets('derrota usa el título de sin movimientos', (tester) async {
      await tester.pumpWidget(_appUnderTest(won: false));
      await tester.pump();
      expect(find.text('¡Sin movimientos!'), findsOneWidget);
    });

    testWidgets('muestra la semilla del controlador con opción de copiado',
        (tester) async {
      final container = ProviderScope.containerOf;
      await tester.pumpWidget(_appUnderTest(won: true));
      final ctx = tester.element(find.byType(GeneratedResultScreen));
      await container(ctx)
          .read(generatedGameControllerProvider.notifier)
          .startNew(GeneratorConfig.create(
              cols: 6, rows: 10, difficulty: Difficulty.easy));
      await tester.pump();

      expect(find.textContaining('555'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    // front#103: "Salir" debe volver al menú SIN borrar la raíz. El flujo real
    // apila la post-partida sobre la raíz '/' (donde vive el AuthGate); el
    // antiguo `pushNamedAndRemoveUntil(home, (_) => false)` la borraba y dejaba
    // el cierre de sesión sin quien conmutara a Login. Aquí la raíz cuenta sus
    // montajes: preservarla ⇒ un montaje; borrarla y re-crearla ⇒ dos.
    testWidgets('Salir vuelve a la raíz del menú sin re-crearla', (tester) async {
      // Arrange
      final navKey = GlobalKey<NavigatorState>();
      var homeMounts = 0;
      final useCase = GenerateBoardUseCase(_FakeGenerator(), _NoopLogger(),
          seedSource: () => 555);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            generatedGameControllerProvider.overrideWith(
              () => GeneratedGameController(
                  useCase, RemoveArrowUseCase(), CommandInvoker()),
            ),
          ],
          child: MaterialApp(
            navigatorKey: navKey,
            theme: AppTheme.dark(),
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            onGenerateRoute: (settings) => switch (settings.name) {
              AppRouter.generatedResult => MaterialPageRoute<void>(
                  settings: RouteSettings(
                      name: settings.name, arguments: (won: true, moves: 7)),
                  builder: (_) => const GeneratedResultScreen(),
                ),
              _ => MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) => _RootProbe(onMount: () => homeMounts++),
                ),
            },
          ),
        ),
      );
      expect(homeMounts, 1);
      navKey.currentState!.pushNamed(AppRouter.generatedResult);
      await tester.pumpAndSettle();
      expect(find.text('Salir'), findsOneWidget);

      // Act
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      // Assert: de vuelta en la MISMA raíz (montada una vez) y sin nada que
      // desapilar ⇒ el AuthGate se preserva y el logout sigue funcionando.
      expect(find.text('home-root'), findsOneWidget);
      expect(navKey.currentState!.canPop(), isFalse);
      expect(homeMounts, 1);
    });
  });
}

/// Raíz de prueba que cuenta sus montajes en `initState`, para distinguir entre
/// PRESERVAR la ruta raíz (un montaje) y BORRARLA + re-crearla (dos).
class _RootProbe extends StatefulWidget {
  final VoidCallback onMount;
  const _RootProbe({required this.onMount});

  @override
  State<_RootProbe> createState() => _RootProbeState();
}

class _RootProbeState extends State<_RootProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home-root')));
}
